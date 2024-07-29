// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App } from "../App.sol";
import { AttackResult, Attack_ } from "../AppStorage.sol";
import { HOLE_CARDS, RANK_JOKER } from "../Constants.sol";
import { BaseFacet } from "./BaseFacet.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract AttcksFacet is BaseFacet {
    event Attack(uint256 indexed id, address indexed attacker, address indexed defender, uint256[HOLE_CARDS] tokenIds);
    event DefendWithJoker(uint256 indexed attackId, uint256 tokenId);
    event Defend(uint256 indexed attackId, uint256[HOLE_CARDS] tokenIds);

    error InvalidAddress();
    error InvalidNumber();
    error NoCard();
    error InvalidNumberOfCards();
    error NotPlayer();
    error Immune();
    error AlreadyUnderAttack();
    error AttackingMax();
    error InsufficientFee();
    error AttackResolving();
    error AttackFinalized();
    error AttackOver();
    error Forbidden();
    error WornOut(uint256 tokenId);
    error NotJoker();
    error NotJokerOwner();
    error AlreadyDefended();

    function attackingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[HOLE_CARDS] memory) {
        return s.attackingTokenIds[attackId];
    }

    function defendingTokenIdsUsedIn(uint256 attackId) external view returns (uint256[HOLE_CARDS] memory) {
        return s.defendingTokenIds[attackId];
    }

    function incomingAttackIdOf(address account) external view returns (uint256) {
        return s.incomingAttackId[account];
    }

    function outgoingAttackIdsOf(address account) external view returns (uint256[] memory) {
        return s.outgoingAttackIds[account];
    }

    function isImmune(address account) public view returns (bool) {
        uint256 lastDefendedAt = s.playerOf[account].lastDefendedAt;
        return lastDefendedAt > 0 && block.timestamp < lastDefendedAt + App.config().immunePeriod;
    }

    function attack(address defender, uint8 bootyTier, uint256[HOLE_CARDS] memory tokenIds) external {
        if (defender == address(0)) revert InvalidAddress();
        if (bootyTier >= 3) revert InvalidNumber();
        if (tokenIds.length == 0) revert NoCard();
        if (tokenIds.length != HOLE_CARDS) revert InvalidNumberOfCards();

        if (s.playerOf[defender].cards == 0) revert NotPlayer();
        if (isImmune(defender)) revert Immune();
        if (s.incomingAttackId[defender] > 0) revert AlreadyUnderAttack();
        if (s.outgoingAttackIds[msg.sender].length >= App.config().maxAttacks) revert AttackingMax();

        App.checkpointUser(msg.sender);
        App.checkpointUser(defender);

        uint256 accAttacker = s.accReward[msg.sender];
        uint256 fee = App.config().attackFees[bootyTier];
        if (accAttacker < fee) revert InsufficientFee();
        s.accReward[msg.sender] = accAttacker - fee;

        if (!s.hasAttacked[msg.sender][defender]) {
            address nftMinter = INFT(s.nft).minter();
            INFTMinter(nftMinter).increaseFreeMintingOf(msg.sender);
            s.hasAttacked[msg.sender][defender] = true;
        }

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];
            App.assertCardAvailable(tokenId);
            s.cardOf[tokenId].underuse = true;
        }

        uint256 id = s.lastAttackId + 1;
        uint8 bootyPercentage = App.config().bootyPercentages[bootyTier];
        s.attacks[id] =
            Attack_(false, false, AttackResult.None, bootyPercentage, msg.sender, defender, uint64(block.timestamp));
        s.lastAttackId = id;
        s.attackingTokenIds[id] = tokenIds;
        s.incomingAttackId[defender] = id;
        s.outgoingAttackIds[msg.sender].push(id);

        TransferLib.transferETH(s.treasury, fee, address(0));

        emit Attack(id, msg.sender, defender, tokenIds);
    }

    function defendWithJoker(uint256 attackId, uint256 tokenId) external {
        Attack_ storage _attack = s.attacks[attackId];
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();
        if (_attack.startedAt + App.config().attackPeriod < block.timestamp) revert AttackOver();
        if (msg.sender != _attack.defender) revert Forbidden();

        if (App.cardDurability(tokenId) == 0) revert WornOut(tokenId);
        if (App.cardRank(tokenId) != RANK_JOKER) revert NotJoker();
        if (msg.sender != IERC721(s.nft).ownerOf(tokenId)) revert NotJokerOwner();

        App.spendCard(tokenId);

        App.checkpointUser(_attack.attacker);
        App.checkpointUser(_attack.defender);

        App.finalizeAttack(attackId, _attack);

        emit DefendWithJoker(attackId, tokenId);
    }

    function defend(uint256 attackId, uint256[HOLE_CARDS] memory tokenIds) external {
        Attack_ storage _attack = s.attacks[attackId];
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();
        if (_attack.startedAt + App.config().attackPeriod < block.timestamp) revert AttackOver();
        if (s.defendingTokenIds[attackId].length > 0) revert AlreadyDefended();

        (address attacker, address defender) = (_attack.attacker, _attack.defender);
        if (msg.sender != defender) revert Forbidden();
        if (tokenIds.length == 0) revert NoCard();
        if (tokenIds.length != HOLE_CARDS) revert InvalidNumberOfCards();

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];
            App.assertCardAvailable(tokenId);
            s.cardOf[tokenId].underuse = true;
        }

        s.defendingTokenIds[attackId] = tokenIds;

        App.checkpointUser(attacker);
        App.checkpointUser(defender);

        emit Defend(attackId, tokenIds);
    }
}
