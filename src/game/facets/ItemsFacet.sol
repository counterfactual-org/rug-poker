// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ITEM_KIND_REPAIR } from "../GameConstants.sol";
import { ItemPrice } from "../GameStorage.sol";
import { Player, Players } from "../models/Players.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract ItemsFacet is BaseFacet {
    using Players for Player;

    struct ItemEntry {
        uint256 itemKind;
        uint256 points;
        uint256 eth;
    }

    error InvalidItem();
    error InsufficientETH();

    event UpdateItemPoints(uint256 indexed itemKind, uint256 points, uint256 eth);
    event BuyItemWithPoints(uint256 indexed itemKind, uint256 amount, uint256 points);
    event BuyItemWithETH(uint256 indexed itemKind, uint256 amount, uint256 eth);

    function availableItems() external view returns (ItemEntry[] memory items) {
        items = new ItemEntry[](1);
        ItemPrice memory price = s.itemPrices[ITEM_KIND_REPAIR];
        items[0] = ItemEntry(ITEM_KIND_REPAIR, price.points, price.eth);
    }

    function updateItemPrice(uint256 itemKind, uint256 points, uint256 eth) external onlyOwner {
        s.itemPrices[itemKind] = ItemPrice(points, eth);

        emit UpdateItemPoints(itemKind, points, eth);
    }

    function buyItemWithPoints(uint256 itemKind, uint256 amount) external {
        Player storage player = Players.getOrRevert(msg.sender);

        ItemPrice memory price = s.itemPrices[itemKind];
        if (price.points == 0) revert InvalidItem();

        uint256 points = amount * price.points;
        player.decrementPoints(points);
        player.incrementItems(itemKind, amount);

        emit BuyItemWithPoints(itemKind, amount, points);
    }

    function buyItemWithETH(uint256 itemKind, uint256 amount) external payable {
        Player storage player = Players.getOrRevert(msg.sender);

        ItemPrice memory price = s.itemPrices[itemKind];
        if (price.eth == 0) revert InvalidItem();

        uint256 eth = amount * price.eth;
        if (msg.value != eth) revert InsufficientETH();

        player.incrementItems(itemKind, amount);

        emit BuyItemWithETH(itemKind, amount, eth);
    }
}
