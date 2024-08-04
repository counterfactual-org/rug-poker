// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { COMMUNITY_CARDS, HOLE_CARDS, MAX_LEVEL } from "../GameConstants.sol";
import { AttackResult, Attack_, GameStorage } from "../GameStorage.sol";
import { Card, Cards } from "./Cards.sol";
import { GameConfig, GameConfigs } from "./GameConfigs.sol";
import { Player, Players } from "./Players.sol";
import { Rewards } from "./Rewards.sol";
import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { ArrayLib } from "src/libraries/ArrayLib.sol";

library Attacks {
    using GameConfigs for GameConfig;
    using Players for Player;
    using Cards for Card;

    uint8 constant MAX_CARD_VALUE = 52;

    event DetermineAttackResult(
        IEvaluator.HandRank indexed rankAttack,
        uint256 evalAttack,
        IEvaluator.HandRank indexed rankDefense,
        uint256 evalDefense,
        AttackResult indexed result
    );

    error InvalidAddress();
    error InvalidNumber();
    error DuplicateTokenIds();
    error NotPlayer();
    error JokerNotAllowed();
    error AttackOver();
    error AlreadyDefended();
    error InvalidNumberOfCards();
    error InvalidNumberOfJokers();
    error NotJoker();
    error InvalidJokerCard();
    error AttackResolving();
    error AttackFinalized();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function get(uint256 id) internal view returns (Attack_ storage self) {
        return gameStorage().attacks[id];
    }

    function init(address attacker, address defender, uint256[HOLE_CARDS] memory tokenIds)
        internal
        returns (Attack_ storage self)
    {
        GameStorage storage s = gameStorage();

        if (defender == address(0)) revert InvalidAddress();
        if (ArrayLib.hasDuplicate(tokenIds)) revert DuplicateTokenIds();

        for (uint256 i; i < HOLE_CARDS; ++i) {
            Card storage card = Cards.get(tokenIds[i]);
            card.assertAvailable(attacker);
            card.markUnderuse();
        }

        uint256 id = s.lastAttackId + 1;
        uint8 level = Cards.lowestLevel(tokenIds);
        s.attacks[id] = Attack_(id, false, false, AttackResult.None, level, attacker, defender, uint64(block.timestamp));
        s.lastAttackId = id;

        s.attackingTokenIds[id] = tokenIds;

        return s.attacks[id];
    }

    function markResolving(Attack_ storage self) internal {
        self.resolving = true;
    }

    function defend(
        Attack_ storage self,
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards
    ) internal {
        GameStorage storage s = gameStorage();

        (uint256 attackId, address defender) = (self.id, self.defender);
        GameConfig memory c = GameConfigs.latest();
        if (self.resolving) revert AttackResolving();
        if (self.finalized) revert AttackFinalized();
        if (self.startedAt + c.attackPeriod < block.timestamp) revert AttackOver();
        if (s.defendingTokenIds[attackId].length > 0) revert AlreadyDefended();

        uint256 jokersLength = jokerTokenIds.length;
        if ((tokenIds.length + jokersLength) != HOLE_CARDS) revert InvalidNumberOfCards();
        if (jokersLength > c.maxJokers || jokersLength != jokerCards.length) revert InvalidNumberOfJokers();

        uint256[HOLE_CARDS] memory ids = _populateDefendingTokenIds(tokenIds, jokerTokenIds, jokerCards);
        if (ArrayLib.hasDuplicate(ids)) revert DuplicateTokenIds();

        for (uint256 i; i < HOLE_CARDS; ++i) {
            Card storage card = Cards.get(ids[i]);
            card.assertAvailable(defender);
            card.markUnderuse();
        }

        s.defendingTokenIds[attackId] = ids;
        s.defendingJokerCards[attackId] = jokerCards;
    }

    function _populateDefendingTokenIds(
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards
    ) private view returns (uint256[HOLE_CARDS] memory ids) {
        uint256 jokersLength = jokerTokenIds.length;
        for (uint256 i; i < HOLE_CARDS; ++i) {
            uint256 tokenId;
            if (i < jokersLength) {
                tokenId = jokerTokenIds[i];
                if (!Cards.get(tokenId).isJoker()) revert NotJoker();
                if (jokerCards[i] >= MAX_CARD_VALUE) revert InvalidJokerCard();
            } else {
                tokenId = tokenIds[i - jokersLength];
                if (Cards.get(tokenId).isJoker()) revert JokerNotAllowed();
            }
            ids[i] = tokenId;
        }
    }

    function determineAttackResult(Attack_ storage self, bytes32 seed) internal {
        GameStorage storage s = gameStorage();

        bytes32 random = keccak256(abi.encodePacked(seed, block.number, block.timestamp));
        uint256 id = self.id;
        uint256[HOLE_CARDS] memory attackingTokenIds = s.attackingTokenIds[id];
        uint256[HOLE_CARDS] memory defendingTokenIds = s.defendingTokenIds[id];
        (IEvaluator.HandRank handAttack, uint256 evalAttack, IEvaluator.HandRank handDefense, uint256 evalDefense) =
            _evaluate(attackingTokenIds, defendingTokenIds, s.defendingJokerCards[id], random);

        AttackResult result;
        if (evalAttack < evalDefense) {
            address attacker = self.attacker;
            Cards.gainXPBatch(attackingTokenIds, uint32(evalDefense - evalAttack));
            Rewards.moveBooty(attacker, self.defender, _bootyPercentage(self.level, defendingTokenIds));
            result = AttackResult.Success;
        } else if (evalAttack > evalDefense) {
            address defender = self.defender;
            Cards.gainXPBatch(defendingTokenIds, uint32(evalAttack - evalDefense));
            _moveBootyCards(id, self.attacker, defender, random);
            result = AttackResult.Fail;
        } else {
            result = AttackResult.Draw;
        }
        self.result = result;

        emit DetermineAttackResult(handAttack, evalAttack, handDefense, evalDefense, result);
    }

    function _bootyPercentage(uint8 attackLevel, uint256[HOLE_CARDS] memory defendingTokenIds)
        private
        view
        returns (uint8)
    {
        GameConfig memory c = GameConfigs.latest();
        uint8 defenseLevel = Cards.highestLevel(defendingTokenIds);
        if (defenseLevel >= attackLevel) return c.minBootyPercentage;
        return (attackLevel - defenseLevel) * (c.maxBootyPercentage - c.minBootyPercentage) / MAX_LEVEL;
    }

    function _evaluate(
        uint256[HOLE_CARDS] memory attackingTokenIds,
        uint256[HOLE_CARDS] memory defendingTokenIds,
        uint8[] memory defendingJokerCards,
        bytes32 random
    )
        private
        view
        returns (
            IEvaluator.HandRank handAttack,
            uint256 evalAttack,
            IEvaluator.HandRank handDefense,
            uint256 evalDefense
        )
    {
        uint256[] memory attackingCards = new uint256[](HOLE_CARDS + COMMUNITY_CARDS);
        uint256[] memory defendingCards = new uint256[](HOLE_CARDS + COMMUNITY_CARDS);
        uint256 jokersLength = defendingJokerCards.length;
        for (uint256 i; i < HOLE_CARDS; ++i) {
            uint8 rankA = Cards.get(attackingTokenIds[i]).rank;
            uint8 suitA = Cards.get(attackingTokenIds[i]).suit;
            attackingCards[i] = rankA * 4 + suitA;
            if (i < jokersLength) {
                defendingCards[i] = defendingJokerCards[i];
                continue;
            }
            uint8 rankD = Cards.get(defendingTokenIds[i]).rank;
            uint8 suitD = Cards.get(defendingTokenIds[i]).suit;
            defendingCards[i] = rankD * 4 + suitD;
        }
        for (uint256 i; i < COMMUNITY_CARDS; ++i) {
            uint8 card = uint8(random[i]) % MAX_CARD_VALUE;
            attackingCards[HOLE_CARDS + i] = card;
            defendingCards[HOLE_CARDS + i] = card;
        }

        (handAttack, evalAttack) = GameConfigs.evaluator().handRank(attackingCards);
        (handDefense, evalDefense) = GameConfigs.evaluator().handRank(defendingCards);
    }

    function _moveBootyCards(uint256 id, address attacker, address defender, bytes32 random) private {
        GameStorage storage s = gameStorage();

        uint256 sharesDelta;
        uint256 bootyCards = uint256(uint8(random[4])) % GameConfigs.latest().maxBootyCards + 1;
        for (uint256 i; i < bootyCards; ++i) {
            uint256 index = uint256(uint8(random[(5 + i) % 32])) % s.attackingTokenIds[id].length;
            uint256 tokenId = s.attackingTokenIds[id][index];
            Card storage card = Cards.get(tokenId);
            if (card.owner != defender) {
                card.owner = defender;
                sharesDelta += card.shares();
            }
        }

        Players.get(attacker).decrementShares(sharesDelta);
        Players.get(defender).incrementShares(sharesDelta);
    }

    function finalize(Attack_ storage self) internal {
        if (self.finalized) revert AttackFinalized();

        GameStorage storage s = gameStorage();

        (uint256 id, address attacker, address defender) = (self.id, self.attacker, self.defender);
        Player storage d = Players.get(defender);
        d.updateLastDefendedAt();

        for (uint256 i; i < s.attackingTokenIds[id].length; ++i) {
            Cards.get(s.attackingTokenIds[id][i]).spend();
        }

        for (uint256 i; i < s.defendingTokenIds[id].length; ++i) {
            Cards.get(s.defendingTokenIds[id][i]).spend();
        }

        self.resolving = false;
        self.finalized = true;
        delete s.attackingTokenIds[id];
        delete s.defendingTokenIds[id];
        delete s.defendingJokerCards[id];
        Players.get(attacker).removeOutgoingAttack(id);
        d.updateIncomingAttack(0);
    }
}
