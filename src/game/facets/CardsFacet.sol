// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ITEM_ID_JOKERIZE, ITEM_ID_REPAIR } from "../GameConstants.sol";
import { Card, Cards } from "../models/Cards.sol";
import { GameConfigs } from "../models/GameConfigs.sol";
import { Player, Players } from "../models/Players.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";
import { ERC1155Lib } from "src/libraries/ERC1155Lib.sol";

contract CardsFacet is BaseGameFacet {
    using Cards for Card;
    using Players for Player;

    event AddCard(address indexed account, uint256 indexed tokenId);
    event RemoveCard(address indexed account, uint256 indexed tokenId);
    event BurnCard(address indexed account, uint256 indexed tokenId);
    event RepairCard(address indexed account, uint256 indexed tokenId, uint8 durability);
    event JokerizeCard(address indexed account, uint256 indexed tokenId);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](11);
        s[0] = this.getCard.selector;
        s[1] = this.cardDurability.selector;
        s[2] = this.cardPower.selector;
        s[3] = this.cardRank.selector;
        s[4] = this.cardSuit.selector;
        s[5] = this.cardLevel.selector;
        s[6] = this.addCard.selector;
        s[7] = this.removeCard.selector;
        s[8] = this.burnCard.selector;
        s[9] = this.repairCard.selector;
        s[10] = this.jokerizeCard.selector;
    }

    function getCard(uint256 tokenId) external view returns (Card memory) {
        Card storage card = Cards.get(tokenId);
        if (card.initialized()) {
            return card;
        }
        return Card(
            tokenId,
            address(0),
            Cards.deriveDurability(tokenId),
            Cards.derivePower(tokenId),
            Cards.deriveRank(tokenId),
            Cards.deriveSuit(tokenId),
            0,
            0,
            false,
            0
        );
    }

    function cardDurability(uint256 tokenId) external view returns (uint8) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.durability : Cards.deriveDurability(tokenId);
    }

    function cardPower(uint256 tokenId) external view returns (uint32) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.power : Cards.derivePower(tokenId);
    }

    function cardRank(uint256 tokenId) external view returns (uint8) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.rank : Cards.deriveRank(tokenId);
    }

    function cardSuit(uint256 tokenId) external view returns (uint8) {
        Card storage card = Cards.get(tokenId);
        return card.initialized() ? card.suit : Cards.deriveSuit(tokenId);
    }

    function cardLevel(uint256 tokenId) external view returns (uint256) {
        return Cards.get(tokenId).level;
    }

    function addCard(uint256 tokenId) external {
        Player storage player = Players.getOrRevert(msg.sender);

        player.checkpoint();
        player.increaseBogoIfHasNotPlayed();

        Card storage card = Cards.get(tokenId);
        if (!card.initialized()) {
            card = Cards.init(tokenId, msg.sender);
        }

        GameConfigs.erc721().transferFrom(msg.sender, address(this), tokenId);

        player.incrementCards();
        player.incrementShares(card.power);
        player.updateLastDefendedAt();

        emit AddCard(msg.sender, tokenId);
    }

    function removeCard(uint256 tokenId) external {
        Player storage player = Players.getOrRevert(msg.sender);
        if (player.avatarTokenId == tokenId) {
            player.removeAvatar();
        }

        Card storage card = Cards.get(tokenId);
        card.assertAvailable(msg.sender, false, true);

        player.checkpoint();
        Rewards.claim(card.owner, card.power);

        card.remove();

        player.decrementCards();
        // if it's wornOut, decrementShares was already called in card.spend() so we don't
        if (!card.wornOut()) {
            player.decrementShares(card.power);
        }

        GameConfigs.erc721().transferFrom(address(this), msg.sender, tokenId);

        emit RemoveCard(msg.sender, tokenId);
    }

    function burnCard(uint256 tokenId) external {
        Player storage player = Players.getOrRevert(msg.sender);
        if (player.avatarTokenId == tokenId) {
            player.removeAvatar();
        }

        Card storage card = Cards.get(tokenId);
        card.assertAvailable(msg.sender, true, false);

        player.checkpoint();

        card.remove();

        player.decrementCards();
        player.decrementShares(card.power);

        GameConfigs.nft().burn(tokenId);

        emit BurnCard(msg.sender, tokenId);
    }

    function repairCard(uint256 tokenId) external {
        Players.getOrRevert(msg.sender);

        Card storage card = Cards.get(tokenId);
        card.assertAvailable(msg.sender, false, false);

        ERC1155Lib.burn(msg.sender, ITEM_ID_REPAIR, 1);
        card.repair();

        emit RepairCard(msg.sender, tokenId, card.durability);
    }

    function jokerizeCard(uint256 tokenId) external {
        Players.getOrRevert(msg.sender);

        Card storage card = Cards.get(tokenId);
        card.assertAvailable(msg.sender, false, false);

        ERC1155Lib.burn(msg.sender, ITEM_ID_JOKERIZE, 1);
        card.jokerize();

        emit JokerizeCard(msg.sender, tokenId);
    }
}
