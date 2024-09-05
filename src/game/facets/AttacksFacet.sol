// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { AttackResult, Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { Player, Players } from "../models/Players.sol";
import { Random } from "../models/Random.sol";
import { RandomizerRequests, RequestAction } from "../models/RandomizerRequests.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract AttacksFacet is BaseGameFacet {
    using Players for Player;
    using Cards for Card;
    using Attacks for Attack_;

    event Flop(uint256 indexed id, address indexed attacker, address indexed defender, uint256[] tokenIds);
    event Submit(uint256 indexed attackId, address indexed from, uint256[] tokenIds, uint8[] jokerCards);
    event ShowDown(uint256 indexed attackId, uint256 randomizerId);
    event FinalizeAttack(uint256 indexed id);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = this.attackingTokenIdsUsedIn.selector;
        s[1] = this.defendingTokenIdsUsedIn.selector;
        s[2] = this.incomingAttackIdsOf.selector;
        s[3] = this.outgoingAttackIdsOf.selector;
        s[4] = this.flop.selector;
        s[5] = this.submit.selector;
        s[6] = this.finalize.selector;
    }

    function attackingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[] memory) {
        return s.attackingTokenIds[attackId];
    }

    function defendingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[] memory) {
        return s.defendingTokenIds[attackId];
    }

    function defendingJokerCardsUsedIn(uint256 attackId) external view returns (uint8[] memory) {
        return s.defendingJokerCards[attackId];
    }

    function incomingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return s.incomingAttackIds[account];
    }

    function outgoingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return s.outgoingAttackIds[account];
    }

    function flop(address defender, uint256[] memory tokenIds) external payable {
        Player storage player = Players.getOrRevert(msg.sender);
        Player storage opponent = Players.getOrRevert(defender);

        player.checkpoint();
        opponent.checkpoint();

        Attack_ storage a = Attacks.init(msg.sender, defender);
        uint256 id = a.id;
        RandomizerRequests.request(RequestAction.Flop, id);

        emit Flop(id, msg.sender, defender, tokenIds);
    }

    function submit(uint256 attackId, uint256[] memory tokenIds, uint8[] memory jokerCards) external payable {
        Attack_ storage a = Attacks.get(attackId);

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        emit Submit(attackId, msg.sender, tokenIds, jokerCards);

        if (a.submit(tokenIds, jokerCards)) {
            RandomizerRequests.request(RequestAction.ShowDown, attackId);
        }
    }

    function finalize(uint256 attackId) external {
        Attack_ storage a = Attacks.get(attackId);

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        a.finalize(AttackResult.Fail);

        Rewards.moveAccReward(a.defender, a.attacker, GameConfigs.latest().maxBootyPercentage);

        emit FinalizeAttack(attackId);
    }
}
