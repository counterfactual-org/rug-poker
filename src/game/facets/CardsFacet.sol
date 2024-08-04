// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Card, Cards } from "../models/Cards.sol";
import { GameConfigs } from "../models/GameConfigs.sol";
import { Player, Players } from "../models/Players.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract CardsFacet is BaseFacet {
    using Cards for Card;
    using Players for Player;

    event AddCard(address indexed account, uint256 indexed tokenId);
    event RemoveCard(address indexed account, uint256 indexed tokenId);
    event BurnCard(address indexed account, uint256 indexed tokenId);

    error NotPlayer();
    error MaxCardsStaked();
    error Forbidden();
    error Underuse();
    error DurationNotElapsed();
    error WornOut();

    function getCard(uint256 tokenId) external view returns (Card memory) {
        return Cards.get(tokenId);
    }

    function cardDurability(uint256 tokenId) external view returns (uint8) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.durability : Cards.deriveDurability(tokenId);
    }

    function cardRank(uint256 tokenId) external view returns (uint8) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.rank : Cards.deriveRank(tokenId);
    }

    function cardSuit(uint256 tokenId) external view returns (uint8) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.suit : Cards.deriveSuit(tokenId);
    }

    function cardShares(uint256 tokenId) external view returns (uint256) {
        return Cards.get(tokenId).shares();
    }

    function addCard(uint256 tokenId) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();
        if (player.cards >= GameConfigs.latest().maxCards) revert MaxCardsStaked();

        player.checkpoint();
        player.increaseFreeMintingIfHasNotPlayed();

        Card storage card = Cards.get(tokenId);
        if (!card.initialized()) {
            card = Cards.init(tokenId, msg.sender);
        }

        GameConfigs.erc721().transferFrom(msg.sender, address(this), tokenId);

        player.incrementCards();
        player.incrementShares(card.shares());
        player.updateLastDefendedAt();

        emit AddCard(msg.sender, tokenId);
    }

    function removeCard(uint256 tokenId) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        Card storage card = Cards.get(tokenId);
        if (card.owner != msg.sender) revert Forbidden();
        if (card.underuse) revert Underuse();
        if (!card.wornOut() && card.durationElapsed()) revert DurationNotElapsed();

        player.checkpoint();

        card.remove();

        player.decrementCards();
        // if it's wornOut, decrementShares was already called in card.spend() so we don't
        if (!card.wornOut()) {
            player.decrementShares(card.shares());
        }

        GameConfigs.erc721().transferFrom(address(this), msg.sender, tokenId);

        emit RemoveCard(msg.sender, tokenId);
    }

    function burnCard(uint256 tokenId) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        Card storage card = Cards.get(tokenId);
        if (card.owner != msg.sender) revert Forbidden();
        if (card.underuse) revert Underuse();
        if (card.durability == 0) revert WornOut();

        player.checkpoint();

        card.remove();

        player.decrementCards();
        player.decrementShares(card.shares());

        GameConfigs.nft().burn(tokenId);

        emit BurnCard(msg.sender, tokenId);
    }
}
