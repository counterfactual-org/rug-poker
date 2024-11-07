// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ItemEntry } from "../GameStorage.sol";
import { GameConfigs } from "../models/GameConfigs.sol";
import { Player, Players } from "../models/Players.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";
import { LibString } from "solmate/utils/LibString.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";
import { ERC1155Lib, ERC1155Storage } from "src/libraries/ERC1155Lib.sol";
import { TokenAttr, TokenAttrType, TokenURILib } from "src/libraries/TokenURILib.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract ItemsFacet is BaseGameFacet {
    using Players for Player;
    using LibString for uint256;

    error InvalidItem();
    error InsufficientETH();

    event UpdateItemEntry(
        uint256 indexed id, string name, string description, string image, uint256 points, uint256 eth
    );
    event BuyItemWithPoints(uint256 indexed id, uint256 amount, uint256 points);
    event BuyItemWithETH(uint256 indexed id, uint256 amount, uint256 eth);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = this.balanceOf.selector;
        s[1] = this.balanceOfBatch.selector;
        s[2] = this.uri.selector;
        s[3] = this.itemEntry.selector;
        s[4] = this.updateItemEntry.selector;
        s[5] = this.buyItemWithPoints.selector;
        s[6] = this.buyItemWithETH.selector;
    }

    function balanceOf(address account, uint256 id) external view returns (uint256 balance) {
        return ERC1155Lib.erc1155Storage().balanceOf[account][id];
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory balances)
    {
        return ERC1155Lib.balanceOfBatch(owners, ids);
    }

    function uri(uint256 id) external view returns (string memory) {
        ItemEntry memory e = s.itemEntries[id];
        TokenAttr[] memory attrs = new TokenAttr[](2);
        attrs[0] = TokenAttr(TokenAttrType.Number, "points", e.points.toString());
        attrs[1] = TokenAttr(TokenAttrType.Number, "eth", e.eth.toString());
        return string(TokenURILib.uri(e.name, e.description, e.image, attrs));
    }

    function itemEntry(uint256 id) external view returns (ItemEntry memory) {
        return s.itemEntries[id];
    }

    function updateItemEntry(
        uint256 id,
        string memory name,
        string memory description,
        string memory image,
        uint256 points,
        uint256 eth
    ) external onlyOwner {
        s.itemEntries[id] = ItemEntry(id, name, description, image, points, eth);

        emit UpdateItemEntry(id, name, description, image, points, eth);
    }

    function buyItemWithPoints(uint256 id, uint256 amount) external {
        Player storage player = Players.getOrRevert(msg.sender);

        ItemEntry memory entry = s.itemEntries[id];
        if (entry.points == 0) revert InvalidItem();

        uint256 points = amount * entry.points;
        player.decrementPoints(points);
        ERC1155Lib.mint(msg.sender, id, amount, "");

        emit BuyItemWithPoints(id, amount, points);
    }

    function buyItemWithETH(uint256 id, uint256 amount) external payable {
        Players.getOrRevert(msg.sender);

        ItemEntry memory entry = s.itemEntries[id];
        if (entry.eth == 0) revert InvalidItem();

        uint256 eth = amount * entry.eth;
        if (msg.value != eth) revert InsufficientETH();

        uint256 fee = eth * 3 / 10;
        TransferLib.transferETH(GameConfigs.treasury(), fee, address(0));
        ERC1155Lib.mint(msg.sender, id, amount, "");

        Rewards.checkpoint();

        emit BuyItemWithETH(id, amount, eth);
    }
}
