// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Card, Cards } from "../models/Cards.sol";
import { Configs } from "../models/Configs.sol";
import { Player, Players } from "../models/Players.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract CardsFacet is BaseFacet {
    using Cards for Card;
    using Players for Player;

    event AddCard(address indexed account, uint256 indexed tokenId);
    event RemoveCard(address indexed account, uint256 indexed tokenId);
    event BurnCard(address indexed account, uint256 indexed tokenId);

    error NotPlayer();

    function getPlayer(address account) external view returns (Player memory) {
        return Players.get(account);
    }

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
        Player storage player = Players.init(msg.sender);
        player.addCard(tokenId);

        emit AddCard(msg.sender, tokenId);
    }

    function removeCard(uint256 tokenId) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        player.removeCard(tokenId);

        emit RemoveCard(msg.sender, tokenId);
    }

    function burnCard(uint256 tokenId) external {
        Player storage player = Players.get(msg.sender);
        if (!player.initialized()) revert NotPlayer();

        player.burnCard(tokenId);

        emit BurnCard(msg.sender, tokenId);
    }
}
