// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { COMMUNITY_CARDS, HOLE_CARDS } from "../Constants.sol";
import { AttackResult, Attack_, GameStorage } from "../GameStorage.sol";
import { Card, Cards } from "./Cards.sol";
import { Config, Configs } from "./Configs.sol";
import { Player, Players } from "./Players.sol";
import { Rewards } from "./Rewards.sol";

import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { ArrayLib } from "src/libraries/ArrayLib.sol";

library Attacks {
    using ArrayLib for uint256[];
    using Configs for Config;
    using Players for Player;
    using Cards for Card;

    uint8 constant MAX_CARD_VALUE = 52;

    event EvaluateAttack(
        IEvaluator.HandRank indexed rankAttack,
        uint256 evalAttack,
        IEvaluator.HandRank indexed rankDefense,
        uint256 evalDefense,
        AttackResult indexed result
    );

    error Forbidden();
    error InvalidAddress();
    error InvalidNumber();
    error DuplicateTokenIds();
    error NotPlayer();
    error Immune();
    error AlreadyUnderAttack();
    error AttackingMax();
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

    function init(address attacker, address defender, uint8 bootyTier, uint256[HOLE_CARDS] memory tokenIds)
        internal
        returns (Attack_ storage self)
    {
        GameStorage storage s = gameStorage();

        if (defender == address(0)) revert InvalidAddress();
        if (bootyTier >= 3) revert InvalidNumber();
        if (ArrayLib.hasDuplicate(tokenIds)) revert DuplicateTokenIds();

        for (uint256 i; i < tokenIds.length; ++i) {
            Card storage card = Cards.get(tokenIds[i]);
            if (card.isJoker()) revert JokerNotAllowed();
            card.assertAvailable(attacker);
            card.markUnderuse();
        }

        uint256 id = s.lastAttackId + 1;
        uint8 booty = Configs.latest().bootyPercentages[bootyTier];
        s.attacks[id] = Attack_(id, false, false, AttackResult.None, booty, attacker, defender, uint64(block.timestamp));
        s.lastAttackId = id;

        s.attackingTokenIds[id] = tokenIds;

        return s.attacks[id];
    }

    function markResolving(Attack_ storage self) internal {
        self.resolving = true;
    }

    function start(Attack_ storage self) internal {
        GameStorage storage s = gameStorage();

        (uint256 id, address attacker, address defender) = (self.id, self.attacker, self.defender);

        Player storage d = Players.get(defender);
        if (!d.initialized()) revert NotPlayer();
        if (d.isImmune()) revert Immune();
        if (s.incomingAttackId[defender] > 0) revert AlreadyUnderAttack();
        if (s.outgoingAttackIds[attacker].length >= Configs.latest().maxAttacks) revert AttackingMax();

        s.incomingAttackId[defender] = id;
        s.outgoingAttackIds[attacker].push(id);
    }

    function defend(
        Attack_ storage self,
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards,
        address sender
    ) internal {
        GameStorage storage s = gameStorage();

        (uint256 attackId, address attacker, address defender) = (self.id, self.attacker, self.defender);
        Config memory c = Configs.latest();
        if (sender != defender) revert Forbidden();
        if (self.resolving) revert AttackResolving();
        if (self.finalized) revert AttackFinalized();
        if (self.startedAt + c.attackPeriod < block.timestamp) revert AttackOver();
        if (s.defendingTokenIds[attackId].length > 0) revert AlreadyDefended();

        uint256 jokersLength = jokerTokenIds.length;
        if ((tokenIds.length + jokersLength) != HOLE_CARDS) revert InvalidNumberOfCards();
        if (jokersLength > c.maxJokers || jokersLength != jokerCards.length) revert InvalidNumberOfJokers();

        s.defendingTokenIds[attackId] = _populateDefendingTokenIds(tokenIds, jokerTokenIds, jokerCards, attacker);
        s.defendingJokerCards[attackId] = jokerCards;
    }

    function _populateDefendingTokenIds(
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards,
        address attacker
    ) private returns (uint256[HOLE_CARDS] memory ids) {
        uint256 jokersLength = jokerTokenIds.length;
        for (uint256 i; i < HOLE_CARDS; ++i) {
            if (i < jokersLength) {
                if (jokerCards[i] >= MAX_CARD_VALUE) revert InvalidJokerCard();
                ids[i] = jokerTokenIds[i];
                if (!Cards.get(ids[i]).isJoker()) revert NotJoker();
            } else {
                ids[i] = tokenIds[i - jokersLength];
                if (Cards.get(ids[i]).isJoker()) revert JokerNotAllowed();
            }
            ids[i] = i < jokersLength ? jokerTokenIds[i] : tokenIds[i - jokersLength];

            Card storage card = Cards.get(ids[i]);
            card.assertAvailable(attacker);
            card.markUnderuse();
        }
        if (ArrayLib.hasDuplicate(ids)) revert DuplicateTokenIds();
    }

    function finalize(Attack_ storage self) internal {
        if (self.finalized) revert AttackFinalized();

        GameStorage storage s = gameStorage();

        (uint256 id, address attacker, address defender) = (self.id, self.attacker, self.defender);
        Players.get(defender).updateLastDefendedAt();

        for (uint256 i; i < s.attackingTokenIds[id].length; ++i) {
            s.cardOf[s.attackingTokenIds[id][i]].spend();
        }

        for (uint256 i; i < s.defendingTokenIds[id].length; ++i) {
            s.cardOf[s.defendingTokenIds[id][i]].spend();
        }

        self.resolving = false;
        self.finalized = true;
        delete s.attackingTokenIds[id];
        delete s.defendingTokenIds[id];
        delete s.defendingJokerCards[id];
        s.outgoingAttackIds[attacker].remove(id);
        s.incomingAttackId[defender] = 0;
    }

    function deriveAttackResult(Attack_ storage self, bytes32 seed) internal {
        GameStorage storage s = gameStorage();

        bytes32 random = keccak256(abi.encodePacked(seed, block.number, block.timestamp));
        uint256 id = self.id;
        AttackResult result =
            _evaluate(s.attackingTokenIds[id], s.defendingTokenIds[id], s.defendingJokerCards[id], random);

        if (result == AttackResult.Success) {
            Rewards.moveBooty(self.attacker, self.defender, self.bootyPercentage);
        } else if (result == AttackResult.Fail) {
            (address attacker, address defender) = (self.attacker, self.defender);
            uint256 sharesDelta;
            uint256 bootyCards = uint256(uint8(random[4])) % Configs.latest().maxBootyCards + 1;
            for (uint256 i; i < bootyCards; ++i) {
                uint256 index = uint256(uint8(random[(5 + i) % 32])) % s.attackingTokenIds[id].length;
                uint256 tokenId = s.attackingTokenIds[id][index];
                Card storage card = Cards.get(tokenId);
                if (card.owner != defender) {
                    card.owner = defender;
                    sharesDelta += card.shares();
                }
            }

            Rewards.decrementShares(attacker, sharesDelta);
            Rewards.incrementShares(defender, sharesDelta);
        }
        self.result = result;
    }

    function _evaluate(
        uint256[HOLE_CARDS] memory attackingTokenIds,
        uint256[HOLE_CARDS] memory defendingTokenIds,
        uint8[] memory defendingJokerCards,
        bytes32 random
    ) internal returns (AttackResult result) {
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

        (IEvaluator.HandRank handAttack, uint256 evalAttack) = Configs.evaluator().handRank(attackingCards);
        (IEvaluator.HandRank handDefense, uint256 evalDefense) = Configs.evaluator().handRank(defendingCards);

        if (evalAttack < evalDefense) {
            result = AttackResult.Success;
        } else if (evalAttack > evalDefense) {
            result = AttackResult.Fail;
        } else {
            result = AttackResult.Draw;
        }

        emit EvaluateAttack(handAttack, evalAttack, handDefense, evalDefense, result);
    }
}
