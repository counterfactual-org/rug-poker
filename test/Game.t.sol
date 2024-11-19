// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DiamondDeployer } from "../script/libraries/DiamondDeployer.sol";
import { Vm, VmLib } from "../script/libraries/VmLib.sol";
import { Test, console } from "forge-std/Test.sol";
import { NFT } from "src/NFT.sol";
import { RANK_JOKER } from "src/game/GameConstants.sol";
import { AttacksFacet } from "src/game/facets/AttacksFacet.sol";
import { Card, CardsFacet } from "src/game/facets/CardsFacet.sol";
import { Player, PlayersFacet } from "src/game/facets/PlayersFacet.sol";
import { MintFacet } from "src/minter/facets/MintFacet.sol";
import { MinterConfig, MinterConfigsFacet } from "src/minter/facets/MinterConfigsFacet.sol";

contract GameTest is Test {
    using VmLib for Vm;

    struct RandomValue {
        bytes32 seed;
        uint256 offset;
    }

    address private constant EVALUATOR9 = 0x3D1D172f4c138425080c46a94C32475A9c9d879a;
    uint256 private constant MIN_DURATION = 7 days;
    uint256 private constant ATTACK_PERIOD = 1 hours;
    uint256 private constant DEFENSE_PERIOD = 24 hours;
    uint8 private constant ACTION_MINT = 0;
    uint8 private constant ACTION_BURN = 1;
    uint8 private constant ACTION_ATTACK = 2;
    uint8 private constant ACTION_ADD = 3;

    address private owner = makeAddr("owner");
    address private treasury = makeAddr("treasury");
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    address private nft;
    address private nftMinter;
    address private game;

    RandomValue private random;

    address[] private users;
    mapping(address => uint256[]) private decks;
    uint8[] private remainingCards;
    uint256[] private attackingTokenIds;
    uint256[] private defendingTokenIds;
    mapping(uint256 => bool) private burned;

    constructor() {
        users.push(alice);
        users.push(bob);
        users.push(charlie);
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"));
        require(block.chainid == 42_161, "NotForked");

        changePrank(owner, owner);

        address cut = vm.computeCreate2Address("DiamondCutFacet");
        address loupe = vm.computeCreate2Address("DiamondLoupeFacet");

        nft = address(new NFT{ salt: 0 }(address(0), "Rug.Poker", "RUG", owner));

        (, game) = DiamondDeployer.deployGame(cut, loupe, nft, EVALUATOR9, treasury, owner);
        NFT(nft).updateApp(game, true);

        (, nftMinter) = DiamondDeployer.deployNFTMinter(cut, loupe, nft, treasury, game, owner);
        NFT(nft).updateMinter(nftMinter);

        bytes32[3] memory usernames = [bytes32(bytes("alice")), "b.o.b", "charl"];
        for (uint256 i; i < 3; ++i) {
            address user = users[i];
            vm.deal(user, 100e18);
            changePrank(user, user);
            _mint(user, 10);
            PlayersFacet(game).createPlayer(usernames[i]);
            NFT(nft).setApprovalForAll(game, true);
            for (uint256 j; j < 5; ++j) {
                uint256 tokenId = 15 * i + j;
                decks[user].push(tokenId);
                CardsFacet(game).addCard(tokenId);
            }
        }
    }

    function test_simulate() public {
        uint256 accRewardSum = _accRewardSum();
        uint256 value = _mintRandom(3);
        assertApproxEqAbs(accRewardSum + value / 2, _accRewardSum(), 3);
        _logReward();

        for (uint256 i; i < 128; ++i) {
            _setSeed(bytes32(i));
            uint8 action = _draw(0, 4);
            if (action == ACTION_MINT) {
                console.log("\n", "iteration ", i, "- MINT");
                accRewardSum = _accRewardSum();
                value = _mintRandom(3);
                if (accRewardSum > 0) {
                    assertApproxEqAbs(accRewardSum + value / 2, _accRewardSum(), 3);
                }
            } else if (action == ACTION_BURN) {
                console.log("\n", "iteration ", i, "- BURN");
                accRewardSum = _accRewardSum();
                _burnRandom(1);
                assertEq(accRewardSum, _accRewardSum());
            } else if (action == ACTION_ATTACK) {
                console.log("\n", "iteration ", i, "- ATTACK");
                uint8 from = _draw(0, 3);
                uint8 to = _draw(1, 3);
                accRewardSum = _accRewardSum();
                _attack(users[from], users[(from + to) % 3]);
                assertEq(accRewardSum, _accRewardSum());
            } else if (action == ACTION_ADD) {
                console.log("\n", "iteration ", i, "- ADD");
                accRewardSum = _accRewardSum();
                _addRandom(10);
                assertEq(accRewardSum, _accRewardSum());
            } else {
                console.log("\n", "iteration ", i, "- REMOVE");
                accRewardSum = _accRewardSum();
                uint256 claimed = _removeRandom(3);
                assertEq(accRewardSum - claimed, _accRewardSum());
            }
            _logReward();
            uint8 h = _draw(12, 24);
            console.log("skipping hours ", h);
            skip(uint256(h) * 1 hours);
        }
    }

    function _username(address user) private view returns (string memory) {
        if (user == alice) return "alice";
        if (user == bob) return "b.o.b";
        if (user == charlie) return "charlie";
        return "UNKNOWN";
    }

    function _attack(address attacker, address defender) private {
        changePrank(attacker, attacker);
        console.log(string.concat(_username(attacker), " is attacking ", _username(defender)));

        vm.recordLogs();
        AttacksFacet(game).flop(defender);
        Vm.Log memory logFlop = _findLog(vm.getRecordedLogs(), "Flop(uint256,address,address)");
        uint256 id = uint256(logFlop.topics[1]);

        delete remainingCards;
        uint8[] memory _remainingCards = AttacksFacet(game).remainingCards(id);
        for (uint256 i; i < _remainingCards.length; ++i) {
            remainingCards.push(_remainingCards[i]);
        }

        delete attackingTokenIds;
        bool attacked = _pickCards(attackingTokenIds, attacker);
        if (!attacked) {
            console.log("\tattack failure due to card shortage");
            skip(1 hours + 1 minutes);
            AttacksFacet(game).finalize(id);
            return;
        }
        AttacksFacet(game).submit(id, attackingTokenIds, new uint8[](0));

        changePrank(defender, defender);
        console.log(string.concat(_username(defender), " is defending against ", _username(attacker)));

        delete defendingTokenIds;
        bool defended = _pickCards(defendingTokenIds, defender);
        if (!defended) {
            console.log("\tdefend failure due to card shortage");
            skip(24 hours + 1 minutes);
            AttacksFacet(game).finalize(id);
            return;
        }

        vm.recordLogs();
        AttacksFacet(game).submit(id, defendingTokenIds, new uint8[](0));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory logResult = _findLog(logs, "DetermineAttackResult(uint256,uint8)");
        Vm.Log memory logMove = _findLog(logs, "MoveAccReward(address,address,uint8,uint256)");
        Vm.Log memory logTransfer = _findLog(logs, "TransferCardOwnership(uint256,address,address)");
        if (logMove.data.length > 0) {
            address from = address(bytes20(logMove.topics[1] << 96));
            address to = address(bytes20(logMove.topics[2] << 96));
            (uint8 percentage, uint256 amount) = abi.decode(logMove.data, (uint8, uint256));
            console.log(string.concat("reward moved from ", _username(from), " to ", _username(to)));
            console.log("\tamount: ", amount);
            console.log("\tpercentage: ", percentage);
        }
        if (logTransfer.topics.length >= 3) {
            uint256 tokenId = uint256(logTransfer.topics[1]);
            address from = address(bytes20(logTransfer.topics[2] << 96));
            address to = address(bytes20(logTransfer.topics[3] << 96));
            console.log(string.concat("card moved from ", _username(from), " to ", _username(to)));
            console.log("\ttokenId: ", tokenId);

            _remove(decks[from], tokenId);
            decks[to].push(tokenId);
        }

        uint8 result = uint8(uint256(logResult.topics[1]));
        if (result == 0) {
            console.log("attack result: none");
        } else if (result == 1) {
            console.log("attack result: success");
        } else if (result == 2) {
            console.log("attack result: failure");
        } else if (result == 3) {
            console.log("attack result: draw");
        }
    }

    function _pickCards(uint256[] storage tokenIds, address picker) private returns (bool) {
        uint256[] storage deck = decks[picker];
        for (uint256 i; i < deck.length; ++i) {
            uint256 tokenId = deck[i];
            Card memory card = CardsFacet(game).getCard(tokenId);
            int256 index = _findIndex(remainingCards, _toValue(card));
            if (card.owner == picker && card.durability > 0 && card.rank != RANK_JOKER && index >= 0) {
                console.log(
                    string.concat("\t", _username(picker), " picked card with tokenId-value"), tokenId, _toValue(card)
                );
                tokenIds.push(tokenId);
                _removeAt(remainingCards, uint256(index));
                if (tokenIds.length == 2) return true;
            }
        }
        return false;
    }

    function _findLog(Vm.Log[] memory logs, string memory signature) private pure returns (Vm.Log memory log) {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == keccak256(bytes(signature))) {
                return logs[i];
            }
        }
    }

    function _accRewardSum() private view returns (uint256) {
        return PlayersFacet(game).accRewardOf(alice, true) + PlayersFacet(game).accRewardOf(bob, true)
            + PlayersFacet(game).accRewardOf(charlie, true);
    }

    function _logReward() private view {
        uint256 a = PlayersFacet(game).accRewardOf(alice, true);
        uint256 b = PlayersFacet(game).accRewardOf(bob, true);
        uint256 c = PlayersFacet(game).accRewardOf(charlie, true);
        console.log("=========================REWARD/SHARES===========================");
        console.log("\talice:\t", a, "\t", PlayersFacet(game).sharesOf(alice));
        console.log("\tb.o.b:\t", b, "\t", PlayersFacet(game).sharesOf(bob));
        console.log("\tcharl:\t", c, "\t", PlayersFacet(game).sharesOf(charlie));
        console.log("\tsum:\t", a + b + c, "\t");
        console.log("\tbal:\t", game.balance);
        console.log("================================================================");
    }

    function _mint(address user, uint256 count) private returns (uint256 value) {
        changePrank(user, user);
        MinterConfig memory config = MinterConfigsFacet(nftMinter).config();
        value = count * config.price;
        if (vm.getBlockTimestamp() < config.initialDiscountUntil) {
            value = value * 7 / 10;
        }
        MintFacet(nftMinter).mint{ value: value }(count);
        console.log(string.concat("\tminted by ", _username(user), " count-value"), count, value);
    }

    function _mintRandom(uint256 loop) private returns (uint256 value) {
        for (uint256 i; i < loop; ++i) {
            uint8 user = _draw(0, 3);
            uint8 count = _draw(1, 11);
            value += _mint(users[user], count);
        }
    }

    function _burnRandom(uint256 loop) private {
        for (uint256 i; i < loop; ++i) {
            uint8 from = _draw(0, 3);
            address user = users[from];
            changePrank(user, user);
            uint256[] storage deck = decks[user];
            if (deck.length == 0) continue;

            uint256 tokenId = deck[_draw(0, uint8(deck.length))];
            Card memory card = CardsFacet(game).getCard(tokenId);
            if (card.owner != user || card.durability == 0) continue;

            CardsFacet(game).burnCard(tokenId);
            console.log(string.concat("\tburned by ", _username(user), " tokenId"), tokenId);
            _remove(deck, tokenId);
            burned[tokenId] = true;
        }
    }

    function _addRandom(uint256 loop) private {
        for (uint256 i; i < loop; ++i) {
            uint256 nextTokenId = NFT(nft).nextTokenId();
            uint256 page = nextTokenId <= 256 ? 0 : _draw(0, uint8(nextTokenId / 256));
            uint256 tokenId = page * 256 + _draw(0, 255);
            if (tokenId >= nextTokenId || burned[tokenId]) continue;

            Card memory card = CardsFacet(game).getCard(tokenId);
            if (card.owner != address(0)) continue;

            address user = NFT(nft).ownerOf(tokenId);
            changePrank(user, user);

            Player memory player = PlayersFacet(game).getPlayer(user);
            uint256[] storage deck = decks[user];
            if (player.cards >= player.maxCards) continue;

            CardsFacet(game).addCard(tokenId);
            deck.push(tokenId);
            console.log(string.concat("\tadded by ", _username(user), " tokenId"), tokenId);
        }
    }

    function _removeRandom(uint256 loop) private returns (uint256 claimed) {
        for (uint256 i; i < loop; ++i) {
            uint8 from = _draw(0, 3);
            address user = users[from];
            changePrank(user, user);
            uint256[] storage deck = decks[user];
            if (deck.length == 0) continue;

            uint256 tokenId = deck[_draw(0, uint8(deck.length))];
            Card memory card = CardsFacet(game).getCard(tokenId);
            if (card.owner != user || card.lastAddedAt + MIN_DURATION >= vm.getBlockTimestamp()) continue;

            vm.recordLogs();
            CardsFacet(game).removeCard(tokenId);
            console.log(string.concat("\tremoved by ", _username(user), " tokenId"), tokenId);
            Vm.Log memory log = _findLog(vm.getRecordedLogs(), "ClaimReward(address,uint256)");
            uint256 amount = abi.decode(log.data, (uint256));
            claimed += amount;
            console.log("\tclaimed amount", amount);
            _remove(deck, tokenId);
        }
    }

    function _setSeed(bytes32 seed) private {
        uint256 bn = vm.getBlockNumber();
        uint256 bt = vm.getBlockTimestamp();
        random.seed = keccak256(abi.encodePacked(seed, bn, bt));
        random.offset = 0;
    }

    function _draw(uint8 min, uint8 max) internal returns (uint8 value) {
        uint256 offset = random.offset;
        value = min + uint8(random.seed[offset]) % (max - min);
        random.offset = (offset + 1) % 32;
    }

    function _findIndex(uint8[] storage list, uint8 target) private view returns (int256) {
        for (uint256 i; i < list.length; ++i) {
            if (list[i] == target) {
                return int256(i);
            }
        }
        return -1;
    }

    function _removeAt(uint8[] storage list, uint256 index) private returns (uint8 elem) {
        elem = list[index];
        list[index] = list[list.length - 1];
        list.pop();
    }

    function _remove(uint256[] storage list, uint256 target) private {
        for (uint256 i; i < list.length; ++i) {
            if (list[i] == target) {
                list[i] = list[list.length - 1];
                list.pop();
                return;
            }
        }
    }

    function _toValue(Card memory self) internal pure returns (uint8) {
        return self.rank * 4 + self.suit;
    }
}
