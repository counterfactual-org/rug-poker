// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {
    ATTACK_ROUNDS,
    CARDS,
    COMMUNITY_CARDS,
    FLOPPED_CARDS,
    HOLE_CARDS,
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
} from "../GameConstants.sol";
import { Card, GameStorage, Player, RandomizerRequest, RequestAction } from "../GameStorage.sol";
import { GameConfig, GameConfigs } from "./GameConfigs.sol";
import { Players } from "./Players.sol";
import { Random } from "./Random.sol";
import { RandomizerRequests } from "./RandomizerRequests.sol";
import { Rewards } from "./Rewards.sol";
import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { ArrayLib } from "src/libraries/ArrayLib.sol";

library Cards {
    using Players for Player;
    using RandomizerRequests for RandomizerRequest;

    uint8 constant FIELD_DURABILITY = 0;
    uint8 constant FIELD_POWER = 1;
    uint8 constant FIELD_RANK = 2;
    uint8 constant FIELD_SUIT = 3;
    uint8 constant MAX_CARD_VALUE = 52;

    event TransferCardOwnership(uint256 indexed tokenId, address indexed from, address indexed to);
    event SpendCard(uint256 indexed tokenId, uint8 durability);
    event CardGainXP(uint256 indexed tokenId, uint32 xp);
    event CardLevelUp(uint256 indexed tokenId, uint8 level, uint8 powerUpPercentage, uint32 powerUp);
    event OnRepair(uint256 indexed tokenId, bool success);
    event OnJokerize(uint256 indexed tokenId, bool success);
    event OnMutateRank(uint256 indexed tokenId, bool success, uint8 rank);
    event OnMutateSuit(uint256 indexed tokenId, bool success, uint8 suit);

    error InvalidNumberOfCards();
    error DuplicateTokenIds();
    error InvalidCard();
    error NotCard();
    error CardAdded(uint256 tokenId);
    error CardNotAdded(uint256 tokenId);
    error Underuse(uint256 tokenId);
    error NotCardOwner(uint256 tokenId);
    error WornOut(uint256 tokenId);
    error DurationNotElapsed(uint256 tokenId);
    error UnableToRepair(uint256 tokenId);
    error IsJoker(uint256 tokenId);

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function assertValidNumberOfCards(uint256 number) internal pure {
        if (number != 2) revert InvalidNumberOfCards();
    }

    function assertNotDuplicate(uint256[] memory ids) internal pure {
        if (ArrayLib.hasDuplicate(ids)) revert DuplicateTokenIds();
    }

    function isValidValue(uint8 value) internal pure returns (bool) {
        return value < MAX_CARD_VALUE;
    }

    function populateAllCards(uint8[] storage cards) internal {
        for (uint8 i; i < MAX_CARD_VALUE; ++i) {
            cards.push(i);
        }
    }

    function drawCard(uint8[] storage remainingCards) internal returns (uint8 card) {
        uint256 length = remainingCards.length;
        uint8 index = Random.draw(0, uint8(length));
        card = remainingCards[index];
        remainingCards[index] = remainingCards[length - 1];
        remainingCards.pop();
    }

    function discardCard(uint8[][ATTACK_ROUNDS] storage communityCards, uint8[] storage remainingCards, uint8 value)
        internal
    {
        for (uint256 i; i < ATTACK_ROUNDS; ++i) {
            for (uint256 j; j < FLOPPED_CARDS; ++j) {
                if (communityCards[i][j] == value) revert InvalidCard();
            }
        }
        for (uint256 i; i < remainingCards.length; ++i) {
            if (remainingCards[i] == value) {
                uint256 length = remainingCards.length;
                remainingCards[i] = remainingCards[length - 1];
                remainingCards.pop();
                return;
            }
        }
    }

    function evaluateHands(
        uint256[] storage attackingTokenIds,
        uint256[] storage defendingTokenIds,
        uint8[] storage attackingJokerCards,
        uint8[] storage defendingJokerCards,
        uint8[][ATTACK_ROUNDS] storage communityCards
    )
        internal
        view
        returns (
            IEvaluator.HandRank[ATTACK_ROUNDS] memory handsAttack,
            uint256[ATTACK_ROUNDS] memory ranksAttack,
            IEvaluator.HandRank[ATTACK_ROUNDS] memory handsDefense,
            uint256[ATTACK_ROUNDS] memory ranksDefense
        )
    {
        uint256 attackingJokerIndex;
        uint256 defendingJokerIndex;
        uint256[] memory attackingCards = new uint256[](CARDS);
        uint256[] memory defendingCards = new uint256[](CARDS);
        for (uint256 i; i < HOLE_CARDS; ++i) {
            Card storage attackingCard = Cards.get(attackingTokenIds[i]);
            attackingCards[i] =
                isJoker(attackingCard) ? attackingJokerCards[attackingJokerIndex++] : toValue(attackingCard);
            Card storage defendingCard = Cards.get(defendingTokenIds[i]);
            defendingCards[i] =
                isJoker(defendingCard) ? defendingJokerCards[defendingJokerIndex++] : toValue(defendingCard);
        }

        for (uint256 i; i < ATTACK_ROUNDS; ++i) {
            for (uint256 j; j < COMMUNITY_CARDS; ++j) {
                attackingCards[HOLE_CARDS + j] = communityCards[i][j];
                defendingCards[HOLE_CARDS + j] = communityCards[i][j];
            }
            IEvaluator evaluator = GameConfigs.evaluator9();
            (handsAttack[i], ranksAttack[i]) = evaluator.handRank(attackingCards);
            (handsDefense[i], ranksDefense[i]) = evaluator.handRank(defendingCards);
        }
    }

    function gainXPBatch(uint256[] memory ids, uint32 xp) internal {
        for (uint256 i; i < ids.length; ++i) {
            gainXP(Cards.get(ids[i]), xp);
        }
    }

    function maxXP(uint8 level) internal pure returns (uint32 xp) {
        return uint32(3000) * level * level + 7000;
    }

    function get(uint256 tokenId) internal view returns (Card storage self) {
        return gameStorage().cards[tokenId];
    }

    function getOrRevert(uint256 tokenId) internal view returns (Card storage self) {
        self = get(tokenId);
        if (!initialized(self)) revert NotCard();
    }

    function init(uint256 tokenId, address owner) internal returns (Card storage self) {
        self = get(tokenId);
        self.tokenId = tokenId;
        self.owner = owner;
        self.durability = deriveDurability(tokenId);
        self.power = derivePower(tokenId);
        self.rank = deriveRank(tokenId);
        self.suit = deriveSuit(tokenId);
        self.level = 1;
        self.lastAddedAt = uint64(block.timestamp);

        emit CardLevelUp(tokenId, 1, 0, 0);
    }

    function initialized(Card storage self) internal view returns (bool) {
        return self.level > 0;
    }

    function added(Card storage self) internal view returns (bool) {
        return self.owner != address(0);
    }

    function wornOut(Card storage self) internal view returns (bool) {
        return self.durability == 0;
    }

    function isJoker(Card storage self) internal view returns (bool) {
        return self.rank == RANK_JOKER;
    }

    function durationElapsed(Card storage self) internal view returns (bool) {
        return self.lastAddedAt + GameConfigs.latest().minDuration < block.timestamp;
    }

    function deriveDurability(uint256 tokenId) internal view returns (uint8) {
        GameConfig memory c = GameConfigs.latest();
        INFT nft = GameConfigs.nft();
        if (INFTMinter(nft.minter()).isAirdrop(tokenId)) return c.minDurability;

        bytes32 data = nft.dataOf(tokenId);
        return c.minDurability + (uint8(data[FIELD_DURABILITY]) % (c.maxDurability - c.minDurability));
    }

    function derivePower(uint256 tokenId) internal view returns (uint32) {
        GameConfig memory c = GameConfigs.latest();
        INFT nft = GameConfigs.nft();
        if (INFTMinter(nft.minter()).isAirdrop(tokenId)) return c.minPower;

        bytes32 data = nft.dataOf(tokenId);
        uint32 range = c.maxPower - c.minPower;
        return c.minPower + (range * uint8(data[FIELD_POWER]) / 256) % range;
    }

    function deriveRank(uint256 tokenId) internal view returns (uint8) {
        INFT nft = GameConfigs.nft();
        bytes32 data = nft.dataOf(tokenId);
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
        if (INFTMinter(nft.minter()).isAirdrop(tokenId) || value < 255) return RANK_ACE;
        return RANK_JOKER;
    }

    function deriveSuit(uint256 tokenId) internal view returns (uint8) {
        bytes32 data = GameConfigs.nft().dataOf(tokenId);
        return uint8(data[FIELD_SUIT]) % 4;
    }

    function toValue(Card storage self) internal view returns (uint8) {
        return self.rank * 4 + self.suit;
    }

    function assertAvailable(Card storage self, address owner, bool assertNotWornOut, bool assertDurationElapsed)
        internal
        view
    {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);
        if (self.underuse) revert Underuse(tokenId);
        if (self.owner != owner) revert NotCardOwner(tokenId);
        if (assertNotWornOut && wornOut(self)) revert WornOut(tokenId);
        if (assertDurationElapsed && !durationElapsed(self)) revert DurationNotElapsed(tokenId);
    }

    function assertRepairable(Card storage self) internal view {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);
        if (self.underuse) revert Underuse(tokenId);
        if (self.durability >= GameConfigs.latest().maxDurability) revert UnableToRepair(tokenId);
    }

    function assertJokerizable(Card storage self) internal view {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);
        if (self.underuse) revert Underuse(tokenId);
        if (isJoker(self)) revert IsJoker(tokenId);
    }

    function assertRankMutable(Card storage self) internal view {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);
        if (self.underuse) revert Underuse(tokenId);
        if (isJoker(self)) revert IsJoker(tokenId);
    }

    function assertSuitMutable(Card storage self) internal view {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);
        if (self.underuse) revert Underuse(tokenId);
    }

    function markUnderuse(Card storage self) internal {
        self.underuse = true;
    }

    function clearUnderuse(Card storage self) internal {
        self.underuse = false;
    }

    function add(Card storage self, address owner) internal {
        uint256 tokenId = self.tokenId;
        if (added(self)) revert CardAdded(tokenId);

        Player storage player = Players.getOrRevert(owner);
        player.checkpoint();
        player.increaseBogoIfHasNotPlayed();

        self.owner = owner;

        GameConfigs.erc721().transferFrom(owner, address(this), tokenId);

        player.incrementCards();
        player.incrementShares(self.power);
        player.updateLastDefendedAt();

        emit TransferCardOwnership(tokenId, address(0), owner);
    }

    function remove(Card storage self) internal {
        (address owner, uint256 tokenId) = (self.owner, self.tokenId);

        Player storage player = Players.getOrRevert(owner);
        if (player.avatarTokenId == tokenId) {
            player.removeAvatar();
        }

        uint256 power = self.power;
        player.checkpoint();
        Rewards.claim(owner, power);

        self.owner = address(0);

        player.decrementCards();
        // if it's wornOut, decrementShares was already called in spend() so we don't
        if (!wornOut(self)) {
            player.decrementShares(power);
        }

        GameConfigs.erc721().transferFrom(address(this), owner, tokenId);

        emit TransferCardOwnership(tokenId, owner, address(0));
    }

    function burn(Card storage self) internal {
        (address owner, uint256 tokenId) = (self.owner, self.tokenId);
        Player storage player = Players.getOrRevert(owner);
        if (player.avatarTokenId == tokenId) {
            player.removeAvatar();
        }

        player.checkpoint();

        self.owner = address(0);

        player.decrementCards();
        player.decrementShares(self.power);

        GameConfigs.nft().burn(tokenId);

        emit TransferCardOwnership(tokenId, owner, address(0));
    }

    function move(Card storage self, address to) internal {
        address from = self.owner;
        if (from != to) {
            uint256 tokenId = self.tokenId;
            Player storage owner = Players.getOrRevert(from);
            if (owner.avatarTokenId == tokenId) {
                owner.removeAvatar();
            }

            self.owner = to;

            Player storage newOwner = Players.getOrRevert(to);
            owner.decrementCards();
            newOwner.incrementCards(true);

            uint256 _shares = self.power;
            owner.decrementShares(_shares);
            newOwner.incrementShares(_shares);

            emit TransferCardOwnership(tokenId, from, to);
        }
    }

    function spend(Card storage self) internal {
        uint8 durability = self.durability;
        self.durability = durability - 1;

        if (durability == 1) {
            Players.get(self.owner).decrementShares(self.power);
        }

        emit SpendCard(self.tokenId, durability - 1);
    }

    function gainXP(Card storage self, uint32 delta) internal {
        GameConfig memory c = GameConfigs.latest();
        uint8 maxLevel = c.maxCardLevel;
        uint8 level = self.level;
        uint32 power = self.power;
        uint32 xp = self.xp;
        uint256 tokenId = self.tokenId;

        emit CardGainXP(tokenId, delta);

        while (level < maxLevel) {
            uint32 max = maxXP(level);
            if (xp + delta >= max) {
                delta -= (max - xp);
                level += 1;
                xp = 0;

                uint8 powerUpPercentage = Random.draw(c.minPowerUpPercentage, c.maxPowerUpPercentage);
                uint32 _power = power;
                power = _power * (100 + powerUpPercentage) / 100;

                emit CardLevelUp(tokenId, level, powerUpPercentage, power - _power);
            } else {
                xp += delta;
                break;
            }
        }
        uint32 powerUp = power - self.power;
        self.level = level;
        self.power = power;
        self.xp = xp;

        if (powerUp > 0) {
            Player storage player = Players.get(self.owner);
            player.checkpoint();
            player.incrementShares(powerUp);
        }
    }

    function onRepair(Card storage self) internal {
        assertRepairable(self);

        // 70% fail - 30% success
        bool success = Random.draw(0, 100) < 30;
        if (!success) {
            burn(self);
        } else {
            uint8 durability = self.durability;
            self.durability = durability + 1;

            if (durability == 0) {
                Players.get(self.owner).incrementShares(self.power);
            }
        }

        emit OnRepair(self.tokenId, success);
    }

    function onJokerize(Card storage self) internal {
        assertJokerizable(self);

        // 90% fail - 10% success
        bool success = Random.draw(0, 100) < 10;
        if (!success) {
            burn(self);
        } else {
            self.rank = RANK_JOKER;
        }

        emit OnJokerize(self.tokenId, success);
    }

    function onMutateRank(Card storage self) internal {
        assertRankMutable(self);

        // 30% fail - 70% success
        bool success = Random.draw(0, 100) < 70;
        uint8 rank;
        if (!success) {
            burn(self);
        } else {
            rank = self.rank;
            self.rank = (rank + Random.draw(1, 13)) % 13;
        }

        emit OnMutateRank(self.tokenId, success, rank);
    }

    function onMutateSuit(Card storage self) internal {
        assertRankMutable(self);

        // 30% fail - 70% success
        bool success = Random.draw(0, 100) < 70;
        uint8 suit;
        if (!success) {
            burn(self);
        } else {
            suit = self.suit;
            self.suit = (suit + Random.draw(1, 4)) % 4;
        }

        emit OnMutateSuit(self.tokenId, success, suit);
    }
}
