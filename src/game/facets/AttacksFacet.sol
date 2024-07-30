// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS } from "../Constants.sol";
import { Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { Configs } from "../models/Configs.sol";

import { Player, Players } from "../models/Players.sol";
import { Randomizers } from "../models/Randomizers.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseFacet } from "./BaseFacet.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract AttcksFacet is BaseFacet, IRandomizerCallback {
    using Players for Player;
    using Cards for Card;
    using Attacks for Attack_;

    event Attack(uint256 indexed id, address indexed attacker, address indexed defender, uint256[HOLE_CARDS] tokenIds);
    event Defend(uint256 indexed attackId, uint256[] tokenIds, uint256[] jokerTokenIds);
    event ResolveAttack(uint256 indexed attackId, uint256 indexed randomizerId);
    event FinalizeAttack(uint256 indexed id);

    error Forbidden();
    error NotPlayer();
    error InvalidNumberOfCards();
    error InvalidNumberOfJokers();
    error InvalidJokerCard();
    error AttackResolving();
    error AttackFinalized();
    error AttackOngoing();

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

    function pendingRandomizerRequest(uint256 id) external view returns (uint256 attackId) {
        return Randomizers.pendingRequest(id);
    }

    function attack(address defender, uint8 bootyTier, uint256[HOLE_CARDS] memory tokenIds) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        player.checkpoint();
        Players.get(defender).checkpoint();

        uint256 fee = player.deductFee(bootyTier);
        TransferLib.transferETH(s.treasury, fee, address(0));

        Attack_ storage a = Attacks.init(msg.sender, defender, bootyTier, tokenIds);
        a.start();

        emit Attack(a.id, msg.sender, defender, tokenIds);
    }

    function defend(
        uint256 attackId,
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards
    ) external {
        Attack_ storage a = Attacks.get(attackId);
        a.defend(tokenIds, jokerTokenIds, jokerCards, msg.sender);

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

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

            uint256 randomizerId = Randomizers.request(address(this), attackId);

            emit ResolveAttack(attackId, randomizerId);
        } else {
            if (block.timestamp <= a.startedAt + Configs.latest().attackPeriod) revert AttackOngoing();

            Rewards.moveBooty(a.attacker, a.defender, a.bootyPercentage);

            a.finalize();

            emit FinalizeAttack(attackId);
        }
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != s.randomizer) revert Forbidden();

        uint256 attackId = Randomizers.getPendingRequest(randomizerId);

        Attack_ storage a = Attacks.get(attackId);

        Players.get(a.attacker).checkpoint();
        Players.get(a.defender).checkpoint();

        a.deriveAttackResult(value);
        a.finalize();
    }
}
