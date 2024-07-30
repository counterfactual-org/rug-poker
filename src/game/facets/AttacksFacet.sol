// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS } from "../Constants.sol";
import { Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { Player, Players } from "../models/Players.sol";
import { BaseFacet } from "./BaseFacet.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract AttcksFacet is BaseFacet {
    using Players for Player;
    using Cards for Card;
    using Attacks for Attack_;

    event Attack(uint256 indexed id, address indexed attacker, address indexed defender, uint256[HOLE_CARDS] tokenIds);
    event Defend(uint256 indexed attackId, uint256[] tokenIds, uint256[] jokerTokenIds);

    error NotPlayer();
    error InvalidNumberOfCards();
    error InvalidNumberOfJokers();
    error InvalidJokerCard();
    error AttackResolving();
    error AttackFinalized();
    error AttackOver();
    error WornOut();
    error NotJoker();
    error AlreadyDefended();
    error DuplicateTokenIds();

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

    function attack(address defender, uint8 bootyTier, uint256[HOLE_CARDS] memory tokenIds) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        player.checkpoint();
        Players.get(defender).checkpoint();

        uint256 fee = player.deductFee(bootyTier);
        TransferLib.transferETH(s.treasury, fee, address(0));

        Attack_ storage _attack = Attacks.init(msg.sender, defender, bootyTier, tokenIds);

        emit Attack(_attack.id, msg.sender, defender, tokenIds);
    }

    function defend(
        uint256 attackId,
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards
    ) external {
        Attack_ storage _attack = Attacks.get(attackId);
        _attack.defend(tokenIds, jokerTokenIds, jokerCards, msg.sender);

        Players.get(_attack.attacker).checkpoint();
        Players.get(_attack.defender).checkpoint();

        emit Defend(attackId, tokenIds, jokerTokenIds);
    }
}
