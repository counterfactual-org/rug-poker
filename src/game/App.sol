// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { AppStorage, Attack_, Card, Config } from "./AppStorage.sol";

import {
    FIELD_DURABILITY,
    FIELD_RANK,
    FIELD_SUIT,
    HOLE_CARDS,
    MAX_DURABILITY,
    MIN_DURABILITY,
    MIN_RANDOMIZER_GAS_LIMIT,
    RANK_ACE,
    RANK_EIGHT,
    RANK_FIVE,
    RANK_FOUR,
    RANK_JACK,
    RANK_JOKER,
    RANK_KING,
    RANK_NINE,
    RANK_QUEEN,
    RANK_SEVEN,
    RANK_SIX,
    RANK_TEN,
    RANK_THREE,
    RANK_TWO
} from "./Constants.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { ArrayLib } from "src/libraries/ArrayLib.sol";
import { Bytes32Lib } from "src/libraries/Bytes32Lib.sol";

library App {
    using Bytes32Lib for bytes32;
    using ArrayLib for uint256[];

    event UpdateRandomizerGasLimit(uint256 gasLimit);
    event UpdateEvaluator(address indexed evaluator);
    event UpdateTreasury(address indexed treasury);
    event UpdateConfig();
    event CheckpointUser(address indexed account);
    event Checkpoint(uint256 accRewardPerShare, uint256 reserve);
    event AdjustShares(address indexed account, uint256 sharesSum, uint256 shares);
    event FinalizeAttack(uint256 indexed id);

    error GasLimitTooLow();
    error InvalidAddress();
    error InvalidNumber();
    error InvalidPeriod();
    error InvalidBootyPercentages();
    error InvalidAttackFees();
    error CardNotAdded(uint256 tokenId);
    error Underuse(uint256 tokenId);
    error NotCardOwner(uint256 tokenId);
    error WornOut(uint256 tokenId);

    function appStorage() internal pure returns (AppStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function config() internal view returns (Config memory) {
        AppStorage storage s = appStorage();

        return s.configs[s.configVersion];
    }

    function cardDurability(uint256 tokenId) internal view returns (uint8) {
        AppStorage storage s = appStorage();

        Card memory card = s.cardOf[tokenId];
        if (card.lastAddedAt > 0) {
            return card.durability;
        }

        address nft = s.nft;
        address minter = INFT(nft).minter();
        bytes32 data = INFT(nft).dataOf(tokenId);
        return INFTMinter(minter).isAirdrop(tokenId)
            ? MIN_DURABILITY
            : MIN_DURABILITY + (uint8(data[FIELD_DURABILITY]) % (MAX_DURABILITY - MIN_DURABILITY));
    }

    function cardRank(uint256 tokenId) internal view returns (uint8) {
        AppStorage storage s = appStorage();

        address nft = s.nft;
        address minter = INFT(nft).minter();
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
        if (INFTMinter(minter).isAirdrop(tokenId) || value < 255) return RANK_ACE;
        return RANK_JOKER;
    }

    function cardSuit(uint256 tokenId) internal view returns (uint8) {
        AppStorage storage s = appStorage();

        bytes32 data = INFT(s.nft).dataOf(tokenId);
        return uint8(data[FIELD_SUIT]) % 4;
    }

    function cardShares(uint256 tokenId) internal view returns (uint256) {
        return cardRank(tokenId) + 2;
    }

    function getAccRewardPerShare(uint256 balance) internal view returns (uint256 accRewardPerShare) {
        AppStorage storage s = appStorage();

        accRewardPerShare = s.accRewardPerShare;
        if (balance > s.reserve) {
            uint256 shares = s.sharesSum;
            if (shares > 0) {
                uint256 newReward = balance - s.reserve;
                accRewardPerShare += newReward * 1e12 / shares;
            }
        }
    }

    function assertCardAvailable(uint256 tokenId, address owner) internal view {
        AppStorage storage s = appStorage();

        Card memory card = s.cardOf[tokenId];
        if (!card.added) revert CardNotAdded(tokenId);
        if (card.underuse) revert Underuse(tokenId);
        if (card.owner != owner) revert NotCardOwner(tokenId);
        if (cardDurability(tokenId) == 0) revert WornOut(tokenId);
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) internal {
        if (_randomizerGasLimit < MIN_RANDOMIZER_GAS_LIMIT) revert GasLimitTooLow();

        appStorage().randomizerGasLimit = _randomizerGasLimit;

        emit UpdateRandomizerGasLimit(_randomizerGasLimit);
    }

    function updateEvaluator(address _evaluator) internal {
        if (_evaluator == address(0)) revert InvalidAddress();

        appStorage().evaluator = _evaluator;

        emit UpdateEvaluator(_evaluator);
    }

    function updateTreasury(address _treasury) internal {
        if (_treasury == address(0)) revert InvalidAddress();

        appStorage().treasury = _treasury;

        emit UpdateTreasury(_treasury);
    }

    function updateConfig(Config memory c) internal {
        if (c.maxCards == 0) revert InvalidNumber();
        if (c.maxJokers == 0 || c.maxJokers > HOLE_CARDS) revert InvalidNumber();
        if (c.maxAttacks == 0) revert InvalidNumber();
        if (c.maxBootyCards == 0 || c.maxBootyCards > HOLE_CARDS) revert InvalidNumber();
        if (c.minDuration < 1 days) revert InvalidPeriod();
        if (c.attackPeriod < 1 hours) revert InvalidPeriod();
        if (
            c.bootyPercentages[0] >= c.bootyPercentages[1] || c.bootyPercentages[1] >= c.bootyPercentages[2]
                || c.bootyPercentages[2] > 50
        ) revert InvalidBootyPercentages();
        if (c.attackFees[0] >= c.attackFees[1] || c.attackFees[1] >= c.attackFees[2]) revert InvalidAttackFees();

        AppStorage storage s = appStorage();
        uint256 version = s.configVersion + 1;
        s.configs[version] = c;
        s.configVersion = version;

        emit UpdateConfig();
    }

    function checkpointUser(address account) internal {
        checkpoint();

        AppStorage storage s = appStorage();

        uint256 shares = s.sharesOf[account];
        if (shares > 0) {
            s.accReward[account] += shares * s.accRewardPerShare / 1e12 - s.rewardDebt[account];
        }

        emit CheckpointUser(account);
    }

    function checkpoint() internal {
        AppStorage storage s = appStorage();

        uint256 _reserve = address(this).balance;
        uint256 _accRewardPerShare = getAccRewardPerShare(_reserve);
        s.accRewardPerShare = _accRewardPerShare;
        s.reserve = _reserve;

        emit Checkpoint(_accRewardPerShare, _reserve);
    }

    function incrementShares(address account, uint256 shares) internal {
        AppStorage storage s = appStorage();

        uint256 sharesSum = s.sharesSum + shares;
        uint256 _shares = s.sharesOf[account] + shares;
        s.sharesSum = sharesSum;
        s.sharesOf[account] = _shares;
        s.rewardDebt[account] = _shares * s.accRewardPerShare / 1e12;

        emit AdjustShares(account, sharesSum, _shares);
    }

    function decrementShares(address account, uint256 shares) internal {
        AppStorage storage s = appStorage();

        uint256 sharesSum = s.sharesSum - shares;
        uint256 _shares = s.sharesOf[account] - shares;
        s.sharesSum = sharesSum;
        s.sharesOf[account] = _shares;
        s.rewardDebt[account] = _shares * s.accRewardPerShare / 1e12;

        emit AdjustShares(account, sharesSum, _shares);
    }

    function finalizeAttack(uint256 attackId, Attack_ storage _attack) internal {
        AppStorage storage s = appStorage();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        s.playerOf[defender].lastDefendedAt = uint64(block.timestamp);

        for (uint256 i; i < s.attackingTokenIds[attackId].length; ++i) {
            spendCard(s.attackingTokenIds[attackId][i]);
        }

        for (uint256 i; i < s.defendingTokenIds[attackId].length; ++i) {
            spendCard(s.defendingTokenIds[attackId][i]);
        }

        _attack.resolving = false;
        _attack.finalized = true;
        delete s.attackingTokenIds[attackId];
        delete s.defendingTokenIds[attackId];
        s.outgoingAttackIds[attacker].remove(attackId);
        s.incomingAttackId[defender] = 0;

        emit FinalizeAttack(attackId);
    }

    function spendCard(uint256 tokenId) internal {
        AppStorage storage s = appStorage();

        Card storage card = s.cardOf[tokenId];
        card.underuse = false;

        uint8 durability = card.durability;
        if (durability == 0) revert WornOut(tokenId);
        card.durability = durability - 1;

        if (durability == 1) {
            address owner = card.owner;
            card.added = false;
            s.playerOf[owner].cards -= 1;

            IERC721(s.nft).transferFrom(address(this), owner, tokenId);
        }
    }
}
