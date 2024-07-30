// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App, Config } from "../App.sol";
import { Card, Player } from "../AppStorage.sol";
import { BaseFacet } from "./BaseFacet.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";

contract CardsFacet is BaseFacet {
    event AddCard(address indexed account, uint256 indexed tokenId);
    event RemoveCard(address indexed account, uint256 indexed tokenId);
    event BurnCard(address indexed account, uint256 indexed tokenId);

    error MaxCardsStaked();
    error WornOut();
    error Forbidden();
    error Underuse();
    error DurationNotElapsed();

    function playerOf(address account) external view returns (Player memory) {
        return s.playerOf[account];
    }

    function cardOf(uint256 tokenId) external view returns (Card memory) {
        return s.cardOf[tokenId];
    }

    function cardDurability(uint256 tokenId) external view returns (uint8) {
        return App.cardDurability(tokenId);
    }

    function cardRank(uint256 tokenId) external view returns (uint8) {
        return App.cardRank(tokenId);
    }

    function cardSuit(uint256 tokenId) external view returns (uint8) {
        return App.cardSuit(tokenId);
    }

    function cardShares(uint256 tokenId) external view returns (uint256) {
        return App.cardShares(tokenId);
    }

    function addCard(uint256 tokenId) external {
        Player storage player = s.playerOf[msg.sender];
        uint256 cards = player.cards;
        if (cards >= App.config().maxCards) revert MaxCardsStaked();
        if (!player.hasPlayed) {
            address nftMinter = INFT(s.nft).minter();
            INFTMinter(nftMinter).increaseFreeMintingOf(msg.sender);
            player.hasPlayed = true;
        }

        App.checkpointUser(msg.sender);

        IERC721(s.nft).transferFrom(msg.sender, address(this), tokenId);

        uint8 durability = App.cardDurability(tokenId);
        if (durability == 0) revert WornOut();
        s.cardOf[tokenId] = Card(durability, true, false, msg.sender, uint64(block.timestamp));
        player.cards = cards + 1;
        player.lastDefendedAt = uint64(block.timestamp);

        App.incrementShares(msg.sender, App.cardShares(tokenId));

        emit AddCard(msg.sender, tokenId);
    }

    function removeCard(uint256 tokenId) external {
        Card memory card = s.cardOf[tokenId];
        if (card.owner != msg.sender) revert Forbidden();
        if (card.underuse) revert Underuse();

        bool wornOut = App.cardDurability(tokenId) == 0;
        if (!wornOut && card.lastAddedAt + App.config().minDuration < block.timestamp) {
            revert DurationNotElapsed();
        }

        App.checkpointUser(card.owner);

        s.cardOf[tokenId].added = false;
        s.playerOf[card.owner].cards -= 1;

        uint256 acc = s.accReward[card.owner];
        uint256 shares = App.cardShares(tokenId);
        uint256 reward = acc * shares / s.sharesOf[card.owner];

        s.accReward[card.owner] = acc - reward;
        s.claimableRewardOf[card.owner] += reward;

        if (!wornOut) {
            App.decrementShares(card.owner, shares);
        }

        IERC721(s.nft).transferFrom(address(this), card.owner, tokenId);

        emit RemoveCard(card.owner, tokenId);
    }

    function burnCard(uint256 tokenId) external {
        Card memory card = s.cardOf[tokenId];
        if (card.owner != msg.sender) revert Forbidden();
        if (card.underuse) revert Underuse();
        if (App.cardDurability(tokenId) == 0) revert WornOut();

        App.checkpointUser(msg.sender);

        s.cardOf[tokenId].added = false;
        s.playerOf[msg.sender].cards -= 1;

        App.decrementShares(msg.sender, App.cardShares(tokenId));

        INFT(s.nft).burn(tokenId);

        emit BurnCard(msg.sender, tokenId);
    }
}
