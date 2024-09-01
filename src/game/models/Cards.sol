// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {
    CARDS,
    HOLE_CARDS,
    HOLE_CARDS_SMALL,
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

library Cards {
    using Players for Player;
    using RandomizerRequests for RandomizerRequest;

    uint8 constant FIELD_DURABILITY = 0;
    uint8 constant FIELD_POWER = 1;
    uint8 constant FIELD_RANK = 2;
    uint8 constant FIELD_SUIT = 3;
    uint8 constant MAX_CARD_VALUE = 52;

    event MoveCard(address indexed from, address indexed to, uint256 indexed tokenId);
    event CardGainXP(uint256 tokenId, uint32 xp);
    event CardLevelUp(uint256 tokenId, uint8 level);

    error CardNotAdded(uint256 tokenId);
    error Underuse(uint256 tokenId);
    error NotCardOwner(uint256 tokenId);
    error WornOut(uint256 tokenId);
    error UnableToRepair(uint256 tokenId);
    error UnableToJokerize(uint256 tokenId);

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function areDistinct(uint256[] memory ids) internal view returns (bool) {
        for (uint256 i; i < ids.length - 1; ++i) {
            for (uint256 j = i + 1; j < ids.length; ++j) {
                Card storage cardA = Cards.get(ids[i]);
                Card storage cardB = Cards.get(ids[j]);
                if (cardA.rank == cardB.rank && cardA.suit == cardB.suit) return true;
            }
        }
        return false;
    }

    function hasValidLength(uint256[] memory ids) internal pure returns (bool) {
        return ids.length == HOLE_CARDS || ids.length == HOLE_CARDS_SMALL;
    }

    function isValidValue(uint8 value) internal pure returns (bool) {
        return value < MAX_CARD_VALUE;
    }

    function evaluateHands(
        uint256[] memory attackingTokenIds,
        uint256[] memory defendingTokenIds,
        uint8[] memory defendingJokerCards
    )
        internal
        returns (
            IEvaluator.HandRank handAttack,
            uint256 rankAttack,
            IEvaluator.HandRank handDefense,
            uint256 rankDefense
        )
    {
        uint256 holeCards = attackingTokenIds.length;
        uint256[] memory attackingCards = new uint256[](CARDS);
        uint256[] memory defendingCards = new uint256[](CARDS);
        uint256 jokersLength = defendingJokerCards.length;
        for (uint256 i; i < holeCards; ++i) {
            Card storage attackingCard = Cards.get(attackingTokenIds[i]);
            attackingCards[i] = attackingCard.rank * 4 + attackingCard.suit;
            if (i < jokersLength) {
                defendingCards[i] = defendingJokerCards[i];
                continue;
            }
            Card storage defendingCard = Cards.get(defendingTokenIds[i]);
            defendingCards[i] = defendingCard.rank * 4 + defendingCard.suit;
        }
        for (uint256 i; i < CARDS - holeCards; ++i) {
            uint8 card = Random.draw(0, MAX_CARD_VALUE);
            attackingCards[holeCards + i] = card;
            defendingCards[holeCards + i] = card;
        }

        IEvaluator evaluator = GameConfigs.evaluator7();
        (handAttack, rankAttack) = evaluator.handRank(attackingCards);
        (handDefense, rankDefense) = evaluator.handRank(defendingCards);
    }

    function gainXPBatch(uint256[] memory ids, uint32 xp) internal {
        for (uint256 i; i < ids.length; ++i) {
            gainXP(Cards.get(ids[i]), xp);
        }
    }

    function maxXP(uint8 level) internal pure returns (uint32 xp) {
        return 3000 * level * level + 7000;
    }

    function get(uint256 tokenId) internal view returns (Card storage self) {
        return gameStorage().cards[tokenId];
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

        emit CardLevelUp(tokenId, 1);
    }

    function initialized(Card storage self) internal view returns (bool) {
        return self.level > 0;
    }

    function added(Card storage self) internal view returns (bool) {
        return self.owner != address(0);
    }

    function wornOut(Card storage self) internal view returns (bool) {
        return initialized(self) && self.durability == 0;
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

    function assertAvailable(Card storage self, address owner) internal view {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);
        if (self.underuse) revert Underuse(tokenId);
        if (self.owner != owner) revert NotCardOwner(tokenId);
        if (self.durability == 0) revert WornOut(tokenId);
    }

    function markUnderuse(Card storage self) internal {
        self.underuse = true;
    }

    function clearUnderuse(Card storage self) internal {
        self.underuse = false;
    }

    function remove(Card storage self) internal {
        uint256 tokenId = self.tokenId;
        if (!added(self)) revert CardNotAdded(tokenId);

        address owner = self.owner;
        self.owner = address(0);

        Rewards.claim(owner, self.power);
    }

    function spend(Card storage self) internal {
        self.underuse = false;

        uint8 durability = self.durability;
        self.durability = durability - 1;

        if (durability == 1) {
            Players.get(self.owner).decrementShares(self.power);
        }
    }

    function move(Card storage self, address to) internal {
        address from = self.owner;
        if (from != to) {
            self.owner = to;

            uint256 _shares = self.power;
            Players.get(from).decrementShares(_shares);
            Players.get(to).incrementShares(_shares);

            emit MoveCard(from, from, self.tokenId);
        }
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
                power = power * (100 + Random.draw(c.minPowerUpPercentage, c.maxPowerUpPercentage)) / 100;
                xp = 0;

                emit CardLevelUp(tokenId, level);
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

    function repair(Card storage self) internal {
        if (self.durability >= GameConfigs.latest().maxDurability) revert UnableToRepair(self.tokenId);

        uint8 durability = self.durability + 1;
        self.durability = durability;
    }

    function jokerize(Card storage self) internal {
        if (isJoker(self)) revert UnableToJokerize(self.tokenId);

        self.rank = RANK_JOKER;
    }
}
