// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract GameConfigsFacet is BaseGameFacet {
    event UpdateRandomizerGasLimit(uint256 gasLimit);
    event UpdateEvaluator(address indexed evaluator);
    event UpdateTreasury(address indexed treasury);
    event UpdateConfig();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](10);
        s[0] = this.nft.selector;
        s[1] = this.randomizer.selector;
        s[2] = this.evaluator.selector;
        s[3] = this.randomizerGasLimit.selector;
        s[4] = this.treasury.selector;
        s[5] = this.config.selector;
        s[6] = this.updateRandomizerGasLimit.selector;
        s[7] = this.updateEvaluator.selector;
        s[8] = this.updateTreasury.selector;
        s[9] = this.updateConfig.selector;
    }

    function nft() external view returns (address) {
        return s.nft;
    }

    function randomizer() external view returns (address) {
        return s.randomizer;
    }

    function evaluator() external view returns (address) {
        return s.evaluator;
    }

    function randomizerGasLimit() external view returns (uint256) {
        return s.randomizerGasLimit;
    }

    function treasury() external view returns (address) {
        return s.treasury;
    }

    function config() external view returns (GameConfig memory) {
        return GameConfigs.latest();
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) external onlyOwner {
        GameConfigs.updateRandomizerGasLimit(_randomizerGasLimit);

        emit UpdateRandomizerGasLimit(_randomizerGasLimit);
    }

    function updateEvaluator(address _evaluator) external onlyOwner {
        GameConfigs.updateEvaluator(_evaluator);

        emit UpdateEvaluator(_evaluator);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        GameConfigs.updateTreasury(_treasury);

        emit UpdateTreasury(_treasury);
    }

    function updateConfig(GameConfig memory c) external {
        GameConfigs.updateConfig(c);

        emit UpdateConfig();
    }
}
