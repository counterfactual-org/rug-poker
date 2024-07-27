// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { Owned } from "solmate/auth/Owned.sol";

import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { IGame } from "src/interfaces/IGame.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { IRandomizer } from "src/interfaces/IRandomizer.sol";

import { ArrayLib } from "src/libraries/ArrayLib.sol";
import { Bytes32Lib } from "src/libraries/Bytes32Lib.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract Game is Owned, IGame {
    using ArrayLib for uint256[];
    using Bytes32Lib for bytes32;

    struct Config {
        uint8 maxCards;
        uint8 maxAttacks;
        uint8 maxBootyCards;
        uint32 minDuration;
        uint32 immunePeriod;
        uint32 attackPeriod;
        uint256[3] attackFees;
    }

    struct Card {
        bool underuse;
        address owner;
        uint64 addedAt;
    }

    struct Player {
        uint256 cards;
        bool hasPlayed;
        uint64 lastDefendedAt;
    }

    struct Attack_ {
        bool resolving;
        bool finalized;
        AttackResult result;
        BootyTier bootyTier;
        address attacker;
        address defender;
        uint64 startedAt;
    }

    enum AttackResult {
        None,
        Success,
        Fail,
        Draw
    }

    enum BootyTier {
        TenPercent,
        ThirtyPercent,
        FiftyPercent
    }

    uint8 public constant RANK_TWO = 0;
    uint8 public constant RANK_THREE = 1;
    uint8 public constant RANK_FOUR = 2;
    uint8 public constant RANK_FIVE = 3;
    uint8 public constant RANK_SIX = 4;
    uint8 public constant RANK_SEVEN = 5;
    uint8 public constant RANK_EIGHT = 6;
    uint8 public constant RANK_NINE = 7;
    uint8 public constant RANK_TEN = 8;
    uint8 public constant RANK_JACK = 9;
    uint8 public constant RANK_QUEEN = 10;
    uint8 public constant RANK_KING = 11;
    uint8 public constant RANK_ACE = 12;
    uint8 public constant RANK_JOKER = 13;

    uint8 public constant SUIT_SPADE = 0;
    uint8 public constant SUIT_HEART = 1;
    uint8 public constant SUIT_DIAMOND = 2;
    uint8 public constant SUIT_CLUB = 3;

    uint8 private constant FIELD_DURABILITY = 0;
    uint8 private constant FIELD_RANK = 1;
    uint8 private constant FIELD_SUIT = 2;

    uint8 public constant MAX_DURABILITY = 8;
    uint8 public constant MAX_AIRDROP_DURABILITY = 3;
    uint256 public constant HOLE_CARDS = 5;
    uint256 public constant COMMUNITY_CARDS = 2;
    uint256 public constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;

    address public immutable nft;
    address public immutable randomizer;
    address public immutable evaluator;
    uint256 public randomizerGasLimit;
    address public treasury;
    Config public config;
    mapping(BootyTier => uint8) private _bootyPercentages;

    uint256 public reserve;
    uint256 public accRewardPerShare;
    mapping(address account => uint256) public claimableRewardOf;
    mapping(address account => uint256) private _accReward;

    mapping(uint256 tokenId => Card) public cardOf;
    mapping(address account => Player) public playerOf;

    uint256 public sharesSum;
    mapping(address account => uint256) public sharesOf;
    mapping(address account => uint256) public rewardDebtOf;

    Attack_[] public attacks;
    mapping(address attacker => mapping(address defender => bool)) public hasAttacked;
    mapping(uint256 attackId => uint256[HOLE_CARDS]) private _attackingTokenIds;
    mapping(uint256 attackId => uint256[HOLE_CARDS]) private _defendingTokenIds;
    mapping(address account => uint256) public incomingAttackIdOf;
    mapping(address account => uint256[]) private _outgoingAttackIds;

    mapping(uint256 randomizerId => uint256 attackId) public pendingRandomizerRequests;

    error GasLimitTooLow();
    error InvalidAddress();
    error InvalidNumber();
    error InvalidPeriod();
    error InvalidPercentage();
    error NoClaimableReward();
    error Forbidden();
    error MaxCardsStaked();
    error DurationNotElapsed();
    error Immune();
    error NotPlayer();
    error AlreadyUnderAttack();
    error AttackingMax();
    error NoCard();
    error InvalidNumberOfCards();
    error InsufficientFee();
    error AlreadyDefended();
    error Underuse(uint256 tokenId);
    error NotCardOwner(uint256 tokenId);
    error JokerNotAvailable(uint256 tokenId);
    error WornOut(uint256 tokenId);
    error AttackResolving();
    error AttackFinalized();
    error AttackOver();
    error AttackOngoing();
    error InvalidRandomizerId();
    error NotJoker();
    error NotJokerOwner();

    event UpdateRandomizerGasLimit(uint256 gasLimit);
    event UpdateTreasury(address indexed treasury);
    event UpdateConfig();
    event ClaimReward(address indexed account, uint256 amount);
    event AddCard(address indexed account, uint256 indexed tokenId);
    event RemoveCard(address indexed account, uint256 indexed tokenId);
    event BurnCard(address indexed account, uint256 indexed tokenId);
    event Attack(uint256 indexed id, address indexed attacker, address indexed defender, uint256[HOLE_CARDS] tokenIds);
    event DefendWithJoker(uint256 indexed attackId, uint256 tokenId);
    event Defend(uint256 indexed attackId, uint256[HOLE_CARDS] tokenIds);
    event ResolveAttack(uint256 indexed attackId, uint256 indexed randomizerId);
    event EvaluateAttack(
        IEvaluator.HandRank indexed rankAttack,
        uint256 evalAttack,
        IEvaluator.HandRank indexed rankDefense,
        uint256 evalDefense,
        AttackResult indexed result
    );
    event FinalizeAttack(uint256 indexed id);
    event Transform(uint256 indexed tokenId, uint8 suit, uint8 rank);
    event CheckpointUser(address indexed account);
    event Checkpoint(uint256 accRewardPerShare, uint256 reserve);

    constructor(
        address _nft,
        address _randomizer,
        uint256 _randomizerGasLimit,
        address _evaluator,
        address _treasury,
        Config memory _config,
        address _owner
    ) Owned(_owner) {
        nft = _nft;
        randomizer = _randomizer;
        randomizerGasLimit = _randomizerGasLimit;
        evaluator = _evaluator;
        treasury = _treasury;
        config = _config;
        _bootyPercentages[BootyTier.TenPercent] = 10;
        _bootyPercentages[BootyTier.ThirtyPercent] = 30;
        _bootyPercentages[BootyTier.FiftyPercent] = 50;

        attacks.push(Attack_(false, false, AttackResult.None, BootyTier.TenPercent, address(0), address(0), 0));
    }

    receive() external payable { }

    function cardDurability(uint256 tokenId) public view returns (uint8) {
        bytes32 data = INFT(nft).dataOf(tokenId);
        bool airdrop = INFT(nft).isAirdrop(tokenId);
        return (uint8(data[FIELD_DURABILITY]) % (airdrop ? MAX_AIRDROP_DURABILITY : MAX_DURABILITY)) + 1;
    }

    function cardRank(uint256 tokenId) public view returns (uint8) {
        bytes32 data = INFT(nft).dataOf(tokenId);
        uint8 value = uint8(data[FIELD_RANK]);
        if (value < 32) return RANK_TWO;
        if (value < 62) return RANK_THREE;
        if (value < 89) return RANK_FOUR;
        if (value < 115) return RANK_FIVE;
        if (value < 139) return RANK_SIX;
        if (value < 161) return RANK_SEVEN;
        if (value < 180) return RANK_EIGHT;
        if (value < 198) return RANK_NINE;
        if (value < 214) return RANK_TEN;
        if (value < 228) return RANK_JACK;
        if (value < 239) return RANK_QUEEN;
        if (value < 249) return RANK_KING;
        if (INFT(nft).isAirdrop(tokenId) || value < 255) return RANK_ACE;
        return RANK_JOKER;
    }

    function cardSuit(uint256 tokenId) public view returns (uint8) {
        bytes32 data = INFT(nft).dataOf(tokenId);
        return uint8(data[FIELD_SUIT]) % 4;
    }

    function accRewardOf(address account) external view returns (uint256) {
        uint256 _accRewardPerShare = _getAccRewardPerShare(address(this).balance);
        return _accReward[account] + sharesOf[account] * _accRewardPerShare / 1e12 - rewardDebtOf[account];
    }

    function _getAccRewardPerShare(uint256 balance) private view returns (uint256 _accRewardPerShare) {
        _accRewardPerShare = accRewardPerShare;
        if (balance > reserve) {
            uint256 shares = sharesSum;
            if (shares > 0) {
                uint256 newReward = balance - reserve;
                _accRewardPerShare += newReward * 1e12 / shares;
            }
        }
    }

    function attackingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[HOLE_CARDS] memory) {
        return _attackingTokenIds[attackId];
    }

    function defendingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[HOLE_CARDS] memory) {
        return _defendingTokenIds[attackId];
    }

    function outgoingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return _outgoingAttackIds[account];
    }

    function isImmune(address account) public view returns (bool) {
        uint256 lastDefendedAt = playerOf[account].lastDefendedAt;
        return lastDefendedAt > 0 && block.timestamp < lastDefendedAt + config.immunePeriod;
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) external onlyOwner {
        if (_randomizerGasLimit < MIN_RANDOMIZER_GAS_LIMIT) revert GasLimitTooLow();

        randomizerGasLimit = _randomizerGasLimit;

        emit UpdateRandomizerGasLimit(_randomizerGasLimit);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();

        treasury = _treasury;

        emit UpdateTreasury(_treasury);
    }

    function updateConfig(Config memory _config) external onlyOwner {
        if (_config.maxCards == 0) revert InvalidNumber();
        if (_config.maxAttacks == 0) revert InvalidNumber();
        if (_config.maxBootyCards == 0 || _config.maxBootyCards > HOLE_CARDS) revert InvalidNumber();
        if (_config.minDuration < 1 days) revert InvalidPeriod();
        if (_config.attackPeriod < 1 hours) revert InvalidPeriod();

        config = _config;

        emit UpdateConfig();
    }

    function claimReward() external {
        uint256 reward = claimableRewardOf[msg.sender];
        if (reward == 0) revert NoClaimableReward();

        claimableRewardOf[msg.sender] = 0;

        TransferLib.transferETH(owner, reward, address(0));

        emit ClaimReward(msg.sender, reward);
    }

    function addCard(uint256 tokenId) external {
        Player storage player = playerOf[msg.sender];
        uint256 cards = player.cards;
        if (cards >= config.maxCards) revert MaxCardsStaked();
        if (!player.hasPlayed) {
            address nftMinter = INFT(nft).minter();
            INFTMinter(nftMinter).increaseFreeMintingOf(msg.sender);
            player.hasPlayed = true;
        }

        _checkpointUser(msg.sender);

        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        cardOf[tokenId] = Card(false, msg.sender, uint64(block.timestamp));
        player.cards = cards + 1;
        player.lastDefendedAt = uint64(block.timestamp);

        _incrementShares(msg.sender, cardRank(tokenId));

        emit AddCard(msg.sender, tokenId);
    }

    function removeCard(uint256 tokenId) external {
        Card memory card = cardOf[tokenId];
        if (card.owner != msg.sender) revert Forbidden();
        if (card.underuse) revert Underuse(tokenId);

        if (cardDurability(tokenId) > 0 && card.addedAt + config.minDuration < block.timestamp) {
            revert DurationNotElapsed();
        }

        _checkpointUser(card.owner);

        delete cardOf[tokenId];
        playerOf[card.owner].cards -= 1;

        uint256 acc = _accReward[card.owner];
        uint256 shares = cardRank(tokenId);
        uint256 reward = acc * shares / sharesOf[card.owner];

        _accReward[card.owner] = acc - reward;
        claimableRewardOf[card.owner] += reward;

        _decrementShares(card.owner, shares);

        IERC721(nft).transferFrom(address(this), owner, tokenId);

        emit RemoveCard(owner, tokenId);
    }

    function burnCard(uint256 tokenId) external {
        Card memory card = cardOf[tokenId];
        if (card.owner != msg.sender) revert Forbidden();
        if (card.underuse) revert Underuse(tokenId);

        _checkpointUser(msg.sender);

        delete cardOf[tokenId];
        playerOf[msg.sender].cards -= 1;

        _decrementShares(msg.sender, cardRank(tokenId));

        INFT(nft).burn(tokenId);

        emit BurnCard(msg.sender, tokenId);
    }

    function attack(address defender, BootyTier bootyTier, uint256[HOLE_CARDS] memory tokenIds) external {
        if (playerOf[defender].cards == 0) revert NotPlayer();
        if (isImmune(defender)) revert Immune();
        if (incomingAttackIdOf[defender] > 0) revert AlreadyUnderAttack();
        if (_outgoingAttackIds[msg.sender].length >= config.maxAttacks) revert AttackingMax();
        if (tokenIds.length == 0) revert NoCard();
        if (tokenIds.length != HOLE_CARDS) revert InvalidNumberOfCards();

        checkpointUser(msg.sender);
        checkpointUser(defender);

        uint256 accAttacker = _accReward[msg.sender];
        uint256 fee = config.attackFees[uint8(bootyTier)];
        if (accAttacker < fee) revert InsufficientFee();
        _accReward[msg.sender] = accAttacker - fee;

        TransferLib.transferETH(treasury, fee * 3 / 10, address(0));
        checkpoint();

        if (!hasAttacked[msg.sender][defender]) {
            address nftMinter = INFT(nft).minter();
            INFTMinter(nftMinter).increaseFreeMintingOf(msg.sender);
            hasAttacked[msg.sender][defender] = true;
        }

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];
            _assertCardAvailable(tokenId);
            cardOf[tokenId].underuse = true;
        }

        uint256 id = attacks.length;
        attacks.push(Attack_(false, false, AttackResult.None, bootyTier, msg.sender, defender, uint64(block.timestamp)));
        _attackingTokenIds[id] = tokenIds;
        incomingAttackIdOf[defender] = id;
        _outgoingAttackIds[msg.sender].push(id);

        emit Attack(id, msg.sender, defender, tokenIds);
    }

    function defendWithJoker(uint256 attackId, uint256 tokenId) external {
        Attack_ storage _attack = attacks[attackId];
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();
        if (_attack.startedAt + config.attackPeriod < block.timestamp) revert AttackOver();
        if (msg.sender != _attack.defender) revert Forbidden();

        if (cardDurability(tokenId) == 0) revert WornOut(tokenId);
        if (cardRank(tokenId) != RANK_JOKER) revert NotJoker();
        if (msg.sender != IERC721(nft).ownerOf(tokenId)) revert NotJokerOwner();

        _spendCard(tokenId);

        checkpointUser(_attack.attacker);
        checkpointUser(_attack.defender);

        _finalizeAttack(attackId, _attack);

        emit DefendWithJoker(attackId, tokenId);
    }

    function defend(uint256 attackId, uint256[HOLE_CARDS] memory tokenIds) external {
        Attack_ storage _attack = attacks[attackId];
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();
        if (_attack.startedAt + config.attackPeriod < block.timestamp) revert AttackOver();
        if (_defendingTokenIds[attackId].length > 0) revert AlreadyDefended();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        if (msg.sender != defender) revert Forbidden();
        if (tokenIds.length == 0) revert NoCard();
        if (tokenIds.length != HOLE_CARDS) revert InvalidNumberOfCards();

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];
            _assertCardAvailable(tokenId);
            cardOf[tokenId].underuse = true;
        }

        _defendingTokenIds[attackId] = tokenIds;

        checkpointUser(attacker);
        checkpointUser(defender);

        emit Defend(attackId, tokenIds);
    }

    function _assertCardAvailable(uint256 tokenId) internal view {
        Card memory card = cardOf[tokenId];
        if (card.underuse) revert Underuse(tokenId);
        if (card.owner != msg.sender) revert NotCardOwner(tokenId);
        if (cardRank(tokenId) == RANK_JOKER) revert JokerNotAvailable(tokenId);
        if (cardDurability(tokenId) == 0) revert WornOut(tokenId);
    }

    function resolveAttack(uint256 attackId) external payable {
        Attack_ storage _attack = attacks[attackId];
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        checkpointUser(attacker);
        checkpointUser(defender);

        if (_defendingTokenIds[attackId].length > 0) {
            _attack.resolving = true;

            address _randomizer = randomizer;
            uint256 fee = IRandomizer(_randomizer).estimateFee(randomizerGasLimit);
            if (address(this).balance < fee) revert InsufficientFee();

            IRandomizer(_randomizer).clientDeposit{ value: fee }(address(this));
            uint256 randomizerId = IRandomizer(_randomizer).request(randomizerGasLimit);
            pendingRandomizerRequests[randomizerId] = attackId;

            emit ResolveAttack(attackId, randomizerId);
        } else {
            if (block.timestamp <= _attack.startedAt + config.attackPeriod) revert AttackOngoing();

            _moveBooty(attacker, defender, _attack.bootyTier);

            _finalizeAttack(attackId, _attack);
        }
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != randomizer) revert Forbidden();

        uint256 attackId = pendingRandomizerRequests[randomizerId];
        if (attackId == 0) revert InvalidRandomizerId();
        delete pendingRandomizerRequests[randomizerId];

        Attack_ storage _attack = attacks[attackId];
        if (_attack.finalized) revert AttackFinalized();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        checkpointUser(attacker);
        checkpointUser(defender);

        bytes32 data = keccak256(abi.encodePacked(value, block.number, block.timestamp));
        AttackResult result = _evaluateAttack(_attackingTokenIds[attackId], _defendingTokenIds[attackId], data);

        if (result == AttackResult.Success) {
            _moveBooty(attacker, defender, _attack.bootyTier);
        } else if (result == AttackResult.Fail) {
            uint256 sharesDelta;
            uint256 bootyCards = uint256(uint8(data[4])) % config.maxBootyCards + 1;
            for (uint256 i; i < bootyCards; ++i) {
                uint256 index = uint256(uint8(data[(5 + i) % 32])) % _attackingTokenIds[attackId].length;
                uint256 _tokenId = _attackingTokenIds[attackId][index];
                if (cardOf[_tokenId].owner != defender) {
                    cardOf[_tokenId].owner = defender;
                    sharesDelta += cardRank(_tokenId);
                }
            }

            _decrementShares(attacker, sharesDelta);
            _incrementShares(defender, sharesDelta);
        }
        _attack.result = result;

        _finalizeAttack(attackId, _attack);
    }

    function _evaluateAttack(
        uint256[HOLE_CARDS] memory attackingTokenIds,
        uint256[HOLE_CARDS] memory defendingTokenIds,
        bytes32 data
    ) internal returns (AttackResult result) {
        uint256[] memory attackingCards = new uint256[](HOLE_CARDS + COMMUNITY_CARDS);
        uint256[] memory defendingCards = new uint256[](HOLE_CARDS + COMMUNITY_CARDS);
        for (uint256 i; i < HOLE_CARDS; ++i) {
            uint8 rankA = cardRank(attackingTokenIds[i]);
            uint8 suitA = cardSuit(attackingTokenIds[i]);
            attackingCards[i] = rankA * 4 + suitA;
            uint8 rankD = cardRank(defendingTokenIds[i]);
            uint8 suitD = cardSuit(defendingTokenIds[i]);
            defendingCards[i] = rankD * 4 + suitD;
        }
        for (uint256 i; i < COMMUNITY_CARDS; ++i) {
            uint8 rank = uint8(data[2 * i]) % 13;
            uint8 suit = uint8(data[2 * i + 1]) % 4;
            attackingCards[HOLE_CARDS + i] = rank * 4 + suit;
            defendingCards[HOLE_CARDS + i] = rank * 4 + suit;
        }

        (IEvaluator.HandRank handAttack, uint256 evalAttack) = IEvaluator(evaluator).handRank(attackingCards);
        (IEvaluator.HandRank handDefense, uint256 evalDefense) = IEvaluator(evaluator).handRank(defendingCards);

        if (evalAttack == evalDefense) {
            result = AttackResult.Draw;
        } else if (evalAttack < evalDefense) {
            result = AttackResult.Success;
        } else if (evalAttack > evalDefense) {
            result = AttackResult.Fail;
        }

        emit EvaluateAttack(handAttack, evalAttack, handDefense, evalDefense, result);
    }

    function _moveBooty(address attacker, address defender, BootyTier bootyTier) internal {
        uint256 reward = _accReward[defender];
        uint256 booty = reward * _bootyPercentages[bootyTier] / 100;

        _accReward[attacker] += booty;
        _accReward[defender] = reward - booty;
    }

    function _finalizeAttack(uint256 attackId, Attack_ storage _attack) internal {
        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        playerOf[defender].lastDefendedAt = uint64(block.timestamp);

        for (uint256 i; i < _attackingTokenIds[attackId].length; ++i) {
            _spendCard(_attackingTokenIds[attackId][i]);
        }

        for (uint256 i; i < _defendingTokenIds[attackId].length; ++i) {
            _spendCard(_defendingTokenIds[attackId][i]);
        }

        _attack.resolving = false;
        _attack.finalized = true;
        delete _attackingTokenIds[attackId];
        delete _defendingTokenIds[attackId];
        _outgoingAttackIds[attacker].remove(attackId);
        incomingAttackIdOf[defender] = 0;

        emit FinalizeAttack(attackId);
    }

    function _spendCard(uint256 tokenId) internal {
        Card storage card = cardOf[tokenId];
        card.underuse = false;

        uint8 durability = cardDurability(tokenId);
        bytes32 data = INFT(nft).dataOf(tokenId);
        INFT(nft).updateData(tokenId, data.setByte(FIELD_DURABILITY, bytes1(--durability)));

        if (durability == 0) {
            delete cardOf[tokenId];
            playerOf[owner].cards -= 1;

            IERC721(nft).transferFrom(address(this), owner, tokenId);
        }
    }

    function _incrementShares(address account, uint256 shares) internal {
        uint256 prev = sharesOf[account];
        sharesSum += shares;
        sharesOf[account] = prev + shares;
        rewardDebtOf[account] = (prev + shares) * accRewardPerShare / 1e12;
    }

    function _decrementShares(address account, uint256 shares) internal {
        uint256 prev = sharesOf[account];
        sharesSum -= shares;
        sharesOf[account] = prev - shares;
        rewardDebtOf[account] = (prev - shares) * accRewardPerShare / 1e12;
    }

    function checkpointUser(address account) public {
        _checkpointUser(account);

        rewardDebtOf[account] = sharesOf[account] * accRewardPerShare / 1e12;
    }

    function _checkpointUser(address account) private {
        checkpoint();

        uint256 shares = sharesOf[account];
        if (shares > 0) {
            _accReward[account] += shares * accRewardPerShare / 1e12 - rewardDebtOf[account];
        }

        emit CheckpointUser(account);
    }

    function checkpoint() public {
        uint256 _reserve = address(this).balance;
        uint256 _accRewardPerShare = _getAccRewardPerShare(_reserve);
        accRewardPerShare = _accRewardPerShare;
        reserve = _reserve;

        emit Checkpoint(_accRewardPerShare, _reserve);
    }
}
