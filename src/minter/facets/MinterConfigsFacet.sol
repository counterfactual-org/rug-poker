// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterConfig, MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract MinterConfigsFacet is BaseFacet {
    event UpdateTreasury(address indexed treasury);
    event UpdateGame(address indexed game);
    event UpdateConfig(MinterConfig config);
    event UpdateMerkleRoot(bytes32 indexed merkleRoot, bool isMerkleRoot);

    function nft() external view returns (address) {
        return s.nft;
    }

    function treasury() external view returns (address) {
        return s.treasury;
    }

    function game() external view returns (address) {
        return s.game;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        MinterConfigs.updateTreasury(_treasury);

        emit UpdateTreasury(_treasury);
    }

    function updateGame(address _game) external onlyOwner {
        MinterConfigs.updateGame(_game);

        emit UpdateGame(_game);
    }

    function updateConfig(MinterConfig memory c) external onlyOwner {
        MinterConfigs.updateConfig(c);

        emit UpdateConfig(c);
    }
}
