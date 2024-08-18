// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

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

    uint32 constant MAX_RANK = 7462;
    uint8 constant MAX_LEVEL = 10;

    event DetermineAttackResult(
        IEvaluator.HandRank indexed handAttack,
        uint256 rankAttack,
        IEvaluator.HandRank indexed handDefense,
        uint256 rankDefense,
        AttackResult indexed result
    );

    error InvalidAddress();
    error InvalidNumberOfCards();
    error DuplicateTokenIds();
    error DuplicateCards();
    error NotPlayer();
    error JokerNotAllowed();
    error AttackOver();
    error AlreadyDefended();
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

    function init(address attacker, address defender, uint256[] memory tokenIds)
        internal
        returns (Attack_ storage self)
    {
        GameStorage storage s = gameStorage();

        if (defender == address(0) || attacker == defender) revert InvalidAddress();
        if (!Cards.hasValidLength(tokenIds)) revert InvalidNumberOfCards();
        if (ArrayLib.hasDuplicate(tokenIds)) revert DuplicateTokenIds();
        if (!Cards.areDistinct(tokenIds)) revert DuplicateCards();

        for (uint256 i; i < tokenIds.length; ++i) {
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
        if ((tokenIds.length + jokersLength) != s.attackingTokenIds[attackId].length) revert InvalidNumberOfCards();
        if (jokersLength > c.maxJokers || jokersLength != jokerCards.length) revert InvalidNumberOfJokers();

        uint256[] memory ids = _populateDefendingTokenIds(tokenIds, jokerTokenIds, jokerCards);
        if (ArrayLib.hasDuplicate(ids)) revert DuplicateTokenIds();
        if (!Cards.areDistinct(ids)) revert DuplicateCards();

        for (uint256 i; i < ids.length; ++i) {
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
    ) private view returns (uint256[] memory ids) {
        uint256 jokersLength = jokerTokenIds.length;
        ids = new uint256[](jokersLength + tokenIds.length);
        for (uint256 i; i < jokersLength; ++i) {
            uint256 tokenId = jokerTokenIds[i];
            if (!Cards.get(tokenId).isJoker()) revert NotJoker();
            if (!Cards.isValidValue(jokerCards[i])) revert InvalidJokerCard();
            ids[i] = tokenId;
        }
        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];
            if (Cards.get(tokenId).isJoker()) revert JokerNotAllowed();
            ids[jokersLength + i] = tokenId;
        }
    }

    function onResolve(Attack_ storage self, bytes32 value) internal {
        Player storage attacker = Players.get(self.attacker);

        attacker.checkpoint();
        attacker.increaseBogoRandomly(value);
        Players.get(self.defender).checkpoint();

        determineAttackResult(self, value);
        finalize(self);
    }

    function determineAttackResult(Attack_ storage self, bytes32 seed) internal {
        GameStorage storage s = gameStorage();

        bytes32 random = keccak256(abi.encodePacked(seed, block.number, block.timestamp));
        uint256 id = self.id;
        uint256[] memory attackingTokenIds = s.attackingTokenIds[id];
        uint256[] memory defendingTokenIds = s.defendingTokenIds[id];
        (IEvaluator.HandRank handAttack, uint256 rankAttack, IEvaluator.HandRank handDefense, uint256 rankDefense) =
            Cards.evaluateHands(attackingTokenIds, defendingTokenIds, s.defendingJokerCards[id], random);

        Cards.gainXPBatch(attackingTokenIds, MAX_RANK - uint32(rankDefense));
        Cards.gainXPBatch(defendingTokenIds, (MAX_RANK - uint32(rankAttack)) / 4);

        AttackResult result = AttackResult.Draw;
        if (rankAttack < rankDefense) {
            address attacker = self.attacker;
            Players.get(attacker).incrementPoints(rankDefense - rankAttack);
            Rewards.moveBooty(self.defender, attacker, _bootyPercentage(self.level, defendingTokenIds));
            result = AttackResult.Success;
        } else if (rankAttack > rankDefense) {
            address defender = self.defender;
            Players.get(defender).incrementPoints(rankAttack - rankDefense);
            _moveBootyCards(id, defender, random);
            result = AttackResult.Fail;
        }
        self.result = result;

        emit DetermineAttackResult(handAttack, rankAttack, handDefense, rankDefense, result);
    }

    function _bootyPercentage(uint8 attackLevel, uint256[] memory defendingTokenIds) private view returns (uint8) {
        GameConfig memory c = GameConfigs.latest();
        uint8 defenseLevel = Cards.highestLevel(defendingTokenIds);
        if (defenseLevel >= attackLevel) return c.minBootyPercentage;
        return (attackLevel - defenseLevel) * (c.maxBootyPercentage - c.minBootyPercentage) / MAX_LEVEL;
    }

    function _moveBootyCards(uint256 id, address to, bytes32 random) private {
        GameStorage storage s = gameStorage();

        uint256 bootyCards = uint256(uint8(random[4])) % GameConfigs.latest().maxBootyCards + 1;
        for (uint256 i; i < bootyCards; ++i) {
            uint256 index = uint256(uint8(random[(5 + i) % 32])) % s.attackingTokenIds[id].length;
            uint256 tokenId = s.attackingTokenIds[id][index];
            Cards.get(tokenId).move(to);
        }
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
