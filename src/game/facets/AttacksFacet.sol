// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS } from "../GameConstants.sol";
import { GameStorage } from "../GameStorage.sol";
import { AttackResult, AttackStatus, Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { Player, Players } from "../models/Players.sol";
import { Random } from "../models/Random.sol";

import { Rewards } from "../models/Rewards.sol";
import { RequestAction, VrfRequests } from "../models/VrfRequests.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract AttacksFacet is BaseGameFacet {
    using Players for Player;
    using Cards for Card;
    using Attacks for Attack_;

    event Flop(uint256 indexed attackId, address indexed attacker, address indexed defender);
    event Submit(uint256 indexed attackId, address indexed from, uint256[] tokenIds, uint8[] jokerCards);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](12);
        s[0] = this.getAttack.selector;
        s[1] = this.attackingTokenIds.selector;
        s[2] = this.defendingTokenIds.selector;
        s[3] = this.remainingCards.selector;
        s[4] = this.attackingJokerCards.selector;
        s[5] = this.defendingJokerCards.selector;
        s[6] = this.communityCards.selector;
        s[7] = this.incomingAttackIdsOf.selector;
        s[8] = this.outgoingAttackIdsOf.selector;
        s[9] = this.flop.selector;
        s[10] = this.submit.selector;
        s[11] = this.finalize.selector;
    }

    function getAttack(uint256 attackId) external view returns (Attack_ memory) {
        return Attacks.get(attackId);
    }

    function attackingTokenIds(uint256 attackId) external view returns (uint256[] memory) {
        return s.attackingTokenIds[attackId];
    }

    function defendingTokenIds(uint256 attackId) external view returns (uint256[] memory) {
        return s.defendingTokenIds[attackId];
    }

    function remainingCards(uint256 attackId) external view returns (uint8[] memory) {
        return s.remainingCards[attackId];
    }

    function attackingJokerCards(uint256 attackId) external view returns (uint8[] memory) {
        return s.attackingJokerCards[attackId];
    }

    function defendingJokerCards(uint256 attackId) external view returns (uint8[] memory) {
        return s.defendingJokerCards[attackId];
    }

    function communityCards(uint256 attackId, uint256 round) external view returns (uint8[] memory) {
        return s.communityCards[attackId][round];
    }

    function incomingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return s.incomingAttackIds[account];
    }

    function outgoingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return s.outgoingAttackIds[account];
    }

    function flop(address defender) external payable {
        Player storage player = Players.getOrRevert(msg.sender);
        Player storage opponent = Players.getOrRevert(defender);

        player.checkpoint();
        opponent.checkpoint();

        Attack_ storage a = Attacks.init(msg.sender, defender);
        uint256 id = a.id;
        VrfRequests.request(RequestAction.Flop, id);

        emit Flop(id, msg.sender, defender);
    }

    function submit(uint256 attackId, uint256[] memory tokenIds, uint8[] memory jokerCards) external payable {
        Attack_ storage a = Attacks.get(attackId);

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        emit Submit(attackId, msg.sender, tokenIds, jokerCards);

        if (a.submit(tokenIds, jokerCards)) {
            VrfRequests.request(RequestAction.ShowDown, attackId);
        }
    }

    function finalize(uint256 attackId) external {
        Attack_ storage a = Attacks.get(attackId);
        a.assertWaiting();

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        if (a.status == AttackStatus.WaitingForAttack) {
            a.finalize(AttackResult.Fail);
            Rewards.moveAccReward(a.attacker, a.defender, GameConfigs.latest().maxBootyPercentage);
        } else if (a.status == AttackStatus.WaitingForDefense) {
            a.finalize(AttackResult.Success);
            Rewards.moveAccReward(a.defender, a.attacker, GameConfigs.latest().maxBootyPercentage);
        }
    }
}
