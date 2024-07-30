// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App } from "../App.sol";

import { AttackResult, Attack_ } from "../AppStorage.sol";
import { COMMUNITY_CARDS, HOLE_CARDS, MAX_CARD_VALUE } from "../Constants.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { IRandomizer } from "src/interfaces/IRandomizer.sol";

contract AttckResolverFacet is BaseFacet {
    event ResolveAttack(uint256 indexed attackId, uint256 indexed randomizerId);
    event EvaluateAttack(
        IEvaluator.HandRank indexed rankAttack,
        uint256 evalAttack,
        IEvaluator.HandRank indexed rankDefense,
        uint256 evalDefense,
        AttackResult indexed result
    );

    error AttackResolving();
    error AttackFinalized();
    error InsufficientFee();
    error AttackOngoing();
    error Forbidden();
    error InvalidRandomizerId();

    function pendingRandomizerRequests(uint256 id) external view returns (uint256 attackId) {
        return s.pendingRandomizerRequests[id];
    }

    function resolveAttack(uint256 attackId) external payable {
        Attack_ storage _attack = s.attacks[attackId];
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        App.checkpointUser(attacker);
        App.checkpointUser(defender);

        if (s.defendingTokenIds[attackId].length > 0) {
            _attack.resolving = true;

            address _randomizer = s.randomizer;
            uint256 _randomizerGasLimit = s.randomizerGasLimit;
            uint256 fee = IRandomizer(_randomizer).estimateFee(_randomizerGasLimit);
            if (address(this).balance < fee) revert InsufficientFee();

            IRandomizer(_randomizer).clientDeposit{ value: fee }(address(this));
            uint256 randomizerId = IRandomizer(_randomizer).request(_randomizerGasLimit);
            s.pendingRandomizerRequests[randomizerId] = attackId;

            emit ResolveAttack(attackId, randomizerId);
        } else {
            if (block.timestamp <= _attack.startedAt + App.config().attackPeriod) revert AttackOngoing();

            _moveBooty(attacker, defender, _attack.bootyPercentage);

            App.finalizeAttack(attackId, _attack);
        }
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != s.randomizer) revert Forbidden();

        uint256 attackId = s.pendingRandomizerRequests[randomizerId];
        if (attackId == 0) revert InvalidRandomizerId();
        delete s.pendingRandomizerRequests[randomizerId];

        Attack_ storage _attack = s.attacks[attackId];
        if (_attack.finalized) revert AttackFinalized();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        App.checkpointUser(attacker);
        App.checkpointUser(defender);

        bytes32 data = keccak256(abi.encodePacked(value, block.number, block.timestamp));
        AttackResult result = _evaluateAttack(
            s.attackingTokenIds[attackId], s.defendingTokenIds[attackId], s.defendingJokerCards[attackId], data
        );

        if (result == AttackResult.Success) {
            _moveBooty(attacker, defender, _attack.bootyPercentage);
        } else if (result == AttackResult.Fail) {
            uint256 sharesDelta;
            uint256 bootyCards = uint256(uint8(data[4])) % App.config().maxBootyCards + 1;
            for (uint256 i; i < bootyCards; ++i) {
                uint256 index = uint256(uint8(data[(5 + i) % 32])) % s.attackingTokenIds[attackId].length;
                uint256 _tokenId = s.attackingTokenIds[attackId][index];
                if (s.cardOf[_tokenId].owner != defender) {
                    s.cardOf[_tokenId].owner = defender;
                    sharesDelta += App.cardShares(_tokenId);
                }
            }

            App.decrementShares(attacker, sharesDelta);
            App.incrementShares(defender, sharesDelta);
        }
        _attack.result = result;

        App.finalizeAttack(attackId, _attack);
    }

    function _evaluateAttack(
        uint256[HOLE_CARDS] memory attackingTokenIds,
        uint256[HOLE_CARDS] memory defendingTokenIds,
        uint8[] memory defendingJokerCards,
        bytes32 data
    ) internal returns (AttackResult result) {
        uint256[] memory attackingCards = new uint256[](HOLE_CARDS + COMMUNITY_CARDS);
        uint256[] memory defendingCards = new uint256[](HOLE_CARDS + COMMUNITY_CARDS);
        uint256 jokersLength = defendingJokerCards.length;
        for (uint256 i; i < HOLE_CARDS; ++i) {
            uint8 rankA = App.cardRank(attackingTokenIds[i]);
            uint8 suitA = App.cardSuit(attackingTokenIds[i]);
            attackingCards[i] = rankA * 4 + suitA;
            if (i < jokersLength) {
                defendingCards[i] = defendingJokerCards[i];
                continue;
            }
            uint8 rankD = App.cardRank(defendingTokenIds[i]);
            uint8 suitD = App.cardSuit(defendingTokenIds[i]);
            defendingCards[i] = rankD * 4 + suitD;
        }
        for (uint256 i; i < COMMUNITY_CARDS; ++i) {
            uint8 card = uint8(data[i]) % MAX_CARD_VALUE;
            attackingCards[HOLE_CARDS + i] = card;
            defendingCards[HOLE_CARDS + i] = card;
        }

        (IEvaluator.HandRank handAttack, uint256 evalAttack) = IEvaluator(s.evaluator).handRank(attackingCards);
        (IEvaluator.HandRank handDefense, uint256 evalDefense) = IEvaluator(s.evaluator).handRank(defendingCards);

        if (evalAttack == evalDefense) {
            result = AttackResult.Draw;
        } else if (evalAttack < evalDefense) {
            result = AttackResult.Success;
        } else if (evalAttack > evalDefense) {
            result = AttackResult.Fail;
        }

        emit EvaluateAttack(handAttack, evalAttack, handDefense, evalDefense, result);
    }

    function _moveBooty(address attacker, address defender, uint8 bootyPercentage) internal {
        uint256 reward = s.accReward[defender];
        uint256 booty = reward * bootyPercentage / 100;

        s.accReward[attacker] += booty;
        s.accReward[defender] = reward - booty;
    }
}
