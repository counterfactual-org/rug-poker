// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App } from "../App.sol";
import { AttackResult, Attack_ } from "../AppStorage.sol";
import { HOLE_CARDS, MAX_CARD_VALUE, RANK_JOKER } from "../Constants.sol";
import { BaseFacet } from "./BaseFacet.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract AttcksFacet is BaseFacet {
    event Attack(uint256 indexed id, address indexed attacker, address indexed defender, uint256[HOLE_CARDS] tokenIds);
    event Defend(uint256 indexed attackId, uint256[] tokenIds, uint256[] jokerTokenIds);

    error InvalidAddress();
    error InvalidNumber();
    error InvalidNumberOfCards();
    error InvalidNumberOfJokers();
    error InvalidJokerCard();
    error NotPlayer();
    error Immune();
    error AlreadyUnderAttack();
    error AttackingMax();
    error InsufficientFee();
    error AttackResolving();
    error AttackFinalized();
    error AttackOver();
    error Forbidden();
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

    function isImmune(address account) public view returns (bool) {
        uint256 lastDefendedAt = s.playerOf[account].lastDefendedAt;
        return lastDefendedAt > 0 && block.timestamp < lastDefendedAt + App.config().immunePeriod;
    }

    function attack(address defender, uint8 bootyTier, uint256[HOLE_CARDS] memory tokenIds) external {
        if (defender == address(0)) revert InvalidAddress();
        if (bootyTier >= 3) revert InvalidNumber();
        _assertNotDuplicate(tokenIds);

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
            App.assertCardAvailable(tokenId, msg.sender);
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

    function defend(
        uint256 attackId,
        uint256[] memory tokenIds,
        uint256[] memory jokerTokenIds,
        uint8[] memory jokerCards
    ) external {
        Attack_ storage _attack = s.attacks[attackId];
        address defender = _attack.defender;
        if (msg.sender != defender) revert Forbidden();
        if (_attack.resolving) revert AttackResolving();
        if (_attack.finalized) revert AttackFinalized();
        if (_attack.startedAt + App.config().attackPeriod < block.timestamp) revert AttackOver();
        if (s.defendingTokenIds[attackId].length > 0) revert AlreadyDefended();

        uint256 jokersLength = jokerTokenIds.length;
        if ((tokenIds.length + jokersLength) != HOLE_CARDS) revert InvalidNumberOfCards();
        if (jokersLength > App.config().maxJokers || jokersLength != jokerCards.length) revert InvalidNumberOfJokers();

        for (uint256 i; i < jokersLength; ++i) {
            if (App.cardRank(jokerTokenIds[i]) != RANK_JOKER) revert NotJoker();
            if (jokerCards[i] >= MAX_CARD_VALUE) revert InvalidJokerCard();
        }

        uint256[HOLE_CARDS] memory ids;
        for (uint256 i; i < HOLE_CARDS; ++i) {
            ids[i] = i < jokersLength ? jokerTokenIds[i] : tokenIds[i - jokersLength];
        }
        _assertNotDuplicate(ids);

        for (uint256 i; i < ids.length; ++i) {
            uint256 tokenId = ids[i];
            App.assertCardAvailable(tokenId, msg.sender);
            s.cardOf[tokenId].underuse = true;
        }

        s.defendingTokenIds[attackId] = ids;
        s.defendingJokerCards[attackId] = jokerCards;

        App.checkpointUser(_attack.attacker);
        App.checkpointUser(defender);

        emit Defend(attackId, tokenIds, jokerTokenIds);
    }

    function _assertNotDuplicate(uint256[HOLE_CARDS] memory tokenIds) internal pure {
        for (uint256 i; i < HOLE_CARDS - 1; ++i) {
            for (uint256 j = i + 1; j < HOLE_CARDS; ++j) {
                if (tokenIds[i] == tokenIds[j]) revert DuplicateTokenIds();
            }
        }
    }
}
