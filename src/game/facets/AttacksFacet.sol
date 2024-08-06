// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS } from "../GameConstants.sol";
import { Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { Player, Players } from "../models/Players.sol";
import { RandomizerRequests, RequestAction } from "../models/RandomizerRequests.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract AttacksFacet is BaseGameFacet {
    using Players for Player;
    using Cards for Card;
    using Attacks for Attack_;

    event Attack(uint256 indexed id, address indexed attacker, address indexed defender, uint256[HOLE_CARDS] tokenIds);
    event Defend(uint256 indexed attackId, uint256[] tokenIds, uint256[] jokerTokenIds);
    event ResolveAttack(uint256 indexed attackId, uint256 indexed randomizerId);
    event FinalizeAttack(uint256 indexed id);

    error NotPlayer();
    error Immune();
    error Forbidden();
    error InvalidNumberOfCards();
    error InvalidNumberOfJokers();
    error InvalidJokerCard();
    error AttackResolving();
    error AttackFinalized();
    error AttackOngoing();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = this.attackingTokenIdsUsedIn.selector;
        s[1] = this.defendingTokenIdsUsedIn.selector;
        s[2] = this.incomingAttackIdOf.selector;
        s[3] = this.outgoingAttackIdsOf.selector;
        s[4] = this.attack.selector;
        s[5] = this.defend.selector;
        s[6] = this.resolveAttack.selector;
    }

    function attackingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[HOLE_CARDS] memory) {
        return s.attackingTokenIds[attackId];
    }

    function defendingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[HOLE_CARDS] memory) {
        return s.defendingTokenIds[attackId];
    }

    function defendingJokerCardsUsedIn(uint256 attackId) external view returns (uint8[] memory) {
        return s.defendingJokerCards[attackId];
    }

    function incomingAttackIdOf(address account) external view returns (uint256) {
        return s.incomingAttackId[account];
    }

    function outgoingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return s.outgoingAttackIds[account];
    }

    function attack(address defender, uint256[HOLE_CARDS] memory tokenIds) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        Player storage d = Players.get(defender);
        if (!d.initialized()) revert NotPlayer();
        if (d.isImmune()) revert Immune();

        player.checkpoint();
        d.checkpoint();

        Attack_ storage a = Attacks.init(msg.sender, defender, tokenIds);
        uint256 id = a.id;
        player.addOutgoingAttack(id);
        d.updateIncomingAttack(id);

        emit Attack(id, msg.sender, defender, tokenIds);
    }

    function defend(
        uint256 attackId,
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards
    ) external {
        Attack_ storage a = Attacks.get(attackId);
        if (a.defender != msg.sender) revert Forbidden();

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        a.defend(tokenIds, jokerTokenIds, jokerCards);

        emit Defend(attackId, tokenIds, jokerTokenIds);
    }

    function resolveAttack(uint256 attackId) external payable {
        Attack_ storage a = Attacks.get(attackId);

        if (a.resolving) revert AttackResolving();
        if (a.finalized) revert AttackFinalized();

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        if (s.defendingTokenIds[attackId].length > 0) {
            a.markResolving();

            uint256 randomizerId = RandomizerRequests.request(RequestAction.Attack, attackId);

            emit ResolveAttack(attackId, randomizerId);
        } else {
            GameConfig memory c = GameConfigs.latest();
            if (block.timestamp <= a.startedAt + c.attackPeriod) revert AttackOngoing();

            Rewards.moveBooty(a.attacker, a.defender, c.maxBootyPercentage);

            a.finalize();

            emit FinalizeAttack(attackId);
        }
    }
}
