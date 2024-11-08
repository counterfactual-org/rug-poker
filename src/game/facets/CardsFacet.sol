// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ITEM_ID_CHANGE_RANK, ITEM_ID_CHANGE_SUIT, ITEM_ID_JOKERIZE, ITEM_ID_REPAIR } from "../GameConstants.sol";
import { Card, Cards } from "../models/Cards.sol";
import { GameConfigs } from "../models/GameConfigs.sol";
import { Items } from "../models/Items.sol";
import { Player, Players } from "../models/Players.sol";
import { RandomizerRequests, RequestAction } from "../models/RandomizerRequests.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";
import { ERC1155Lib } from "src/libraries/ERC1155Lib.sol";

contract CardsFacet is BaseGameFacet {
    using Cards for Card;
    using Players for Player;

    event RepairCard(address indexed account, uint256 indexed tokenId, uint8 durability);
    event JokerizeCard(address indexed account, uint256 indexed tokenId);
    event MutateCardRank(address indexed account, uint256 indexed tokenId);
    event MutateCardSuit(address indexed account, uint256 indexed tokenId);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](13);
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
        s[11] = this.mutateCardRank.selector;
        s[12] = this.mutateCardSuit.selector;
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
        Card storage card = Cards.get(tokenId);
        if (!card.initialized()) {
            card = Cards.init(tokenId, address(0));
        }
        card.add(msg.sender);
    }

    function removeCard(uint256 tokenId) external {
        Card storage card = Cards.getOrRevert(tokenId);
        card.assertAvailable(msg.sender, false, true);
        card.remove();
    }

    function burnCard(uint256 tokenId) external {
        Card storage card = Cards.getOrRevert(tokenId);
        card.assertAvailable(msg.sender, true, false);
        card.burn();
    }

    function repairCard(uint256 tokenId) external {
        Players.getOrRevert(msg.sender);

        Card storage card = Cards.getOrRevert(tokenId);
        card.assertRepairable();

        Items.spend(ITEM_ID_REPAIR, msg.sender);

        RandomizerRequests.request(RequestAction.RepairCard, tokenId);

        emit RepairCard(msg.sender, tokenId, card.durability);
    }

    function jokerizeCard(uint256 tokenId) external {
        Players.getOrRevert(msg.sender);

        Card storage card = Cards.getOrRevert(tokenId);
        card.assertJokerizable();

        Items.spend(ITEM_ID_JOKERIZE, msg.sender);

        RandomizerRequests.request(RequestAction.JokerizeCard, tokenId);

        emit JokerizeCard(msg.sender, tokenId);
    }

    function mutateCardRank(uint256 tokenId) external {
        Players.getOrRevert(msg.sender);

        Card storage card = Cards.getOrRevert(tokenId);
        card.assertRankMutable();

        Items.spend(ITEM_ID_CHANGE_RANK, msg.sender);

        RandomizerRequests.request(RequestAction.MutateRank, tokenId);

        emit MutateCardRank(msg.sender, tokenId);
    }

    function mutateCardSuit(uint256 tokenId) external {
        Players.getOrRevert(msg.sender);

        Card storage card = Cards.getOrRevert(tokenId);
        card.assertSuitMutable();

        Items.spend(ITEM_ID_CHANGE_RANK, msg.sender);

        RandomizerRequests.request(RequestAction.MutateSuit, tokenId);

        emit MutateCardSuit(msg.sender, tokenId);
    }
}
