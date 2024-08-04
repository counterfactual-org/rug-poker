// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ITEM_KIND_REPAIR } from "../GameConstants.sol";
import { Player, Players } from "../models/Players.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract ItemsFacet is BaseFacet {
    using Players for Player;

    struct ItemEntry {
        uint256 itemKind;
        uint256 points;
    }

    error InvalidItem();

    event UpdateItemPoints(uint256 indexed itemKind, uint256 points);
    event BuyItem(uint256 indexed itemKind, uint256 amount, uint256 points);

    function availableItems() external view returns (ItemEntry[] memory items) {
        items = new ItemEntry[](1);
        items[0] = ItemEntry(ITEM_KIND_REPAIR, s.itemPoints[ITEM_KIND_REPAIR]);
    }

    function updateItemPoints(uint256 itemKind, uint256 points) external onlyOwner {
        s.itemPoints[itemKind] = points;

        emit UpdateItemPoints(itemKind, points);
    }

    function buyItem(uint256 itemKind, uint256 amount) external {
        Player storage player = Players.getOrRevert(msg.sender);

        if (itemKind == ITEM_KIND_REPAIR) {
            uint256 points = amount * s.itemPoints[itemKind];
            player.decrementPoints(points);
            player.incrementItems(itemKind, amount);

            emit BuyItem(itemKind, amount, points);
        } else {
            revert InvalidItem();
        }
    }
}
