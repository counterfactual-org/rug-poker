// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterConfig, MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseMinterFacet } from "./BaseMinterFacet.sol";

contract MinterConfigsFacet is BaseMinterFacet {
    event UpdateTreasury(address indexed treasury);
    event UpdateGame(address indexed game);
    event UpdateConfig(MinterConfig config);
    event UpdateMerkleRoot(bytes32 indexed merkleRoot, bool isMerkleRoot);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = this.nft.selector;
        s[1] = this.treasury.selector;
        s[2] = this.game.selector;
        s[3] = this.config.selector;
        s[4] = this.updateTreasury.selector;
        s[5] = this.updateGame.selector;
        s[6] = this.updateConfig.selector;
    }

    function nft() external view returns (address) {
        return s.nft;
    }

    function treasury() external view returns (address) {
        return s.treasury;
    }

    function game() external view returns (address) {
        return s.game;
    }

    function config() external view returns (MinterConfig memory) {
        return MinterConfigs.latest();
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
