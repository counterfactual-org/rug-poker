// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript } from "./BaseScript.s.sol";

uint256 constant ITEM_ID_REPAIR = 0;
uint256 constant ITEM_ID_JOKERIZE = 1;
uint256 constant ITEM_ID_CHANGE_RANK = 2;
uint256 constant ITEM_ID_CHANGE_SUIT = 3;

interface IItemFacet_ {
    function updateItemEntry(
        uint256 id,
        string memory name,
        string memory description,
        string memory image,
        uint256 points,
        uint256 eth
    ) external;
}

contract AddItemEntriesScript is BaseScript {
    function _run(uint256, address) internal override {
        bool staging = _isStaging();
        address game = _loadDeployment("Game");

        IItemFacet_(game).updateItemEntry(
            ITEM_ID_REPAIR,
            "Battery Recharger",
            "Use this item for a 30% chance to increase a card's battery by one permanently.",
            "",
            staging ? 100 : 10_000,
            staging ? 0.0002e18 : 0.02e18
        );
        IItemFacet_(game).updateItemEntry(
            ITEM_ID_JOKERIZE,
            "Jokerizer",
            "Use this item for a 10% chance to turn any card into a joker permanently.",
            "",
            staging ? 150 : 15_000,
            staging ? 0.0003e18 : 0.03e18
        );
        IItemFacet_(game).updateItemEntry(
            ITEM_ID_CHANGE_RANK,
            "Number Shifter",
            "Use this item for a 70% chance to randomly change a card's number permanently.",
            "",
            staging ? 150 : 15_000,
            staging ? 0.0003e18 : 0.03e18
        );
        IItemFacet_(game).updateItemEntry(
            ITEM_ID_CHANGE_SUIT,
            "Shape Shifter",
            "Use this item for a 70% chance to randomly change a card's shape permanently.",
            "",
            staging ? 100 : 10_000,
            staging ? 0.0002e18 : 0.02e18
        );
    }
}
