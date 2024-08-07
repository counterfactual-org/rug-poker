// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract GameConfigsFacet is BaseGameFacet {
    event UpdateRandomizerGasLimit(uint256 gasLimit);
    event UpdateEvaluator5(address indexed evaluator);
    event UpdateEvaluator7(address indexed evaluator);
    event UpdateTreasury(address indexed treasury);
    event UpdateConfig();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](12);
        s[0] = this.nft.selector;
        s[1] = this.randomizer.selector;
        s[2] = this.evaluator5.selector;
        s[3] = this.evaluator7.selector;
        s[4] = this.randomizerGasLimit.selector;
        s[5] = this.treasury.selector;
        s[6] = this.config.selector;
        s[7] = this.updateRandomizerGasLimit.selector;
        s[8] = this.updateEvaluator5.selector;
        s[9] = this.updateEvaluator7.selector;
        s[10] = this.updateTreasury.selector;
        s[11] = this.updateConfig.selector;
    }

    function nft() external view returns (address) {
        return s.nft;
    }

    function randomizer() external view returns (address) {
        return s.randomizer;
    }

    function evaluator5() external view returns (address) {
        return s.evaluator5;
    }

    function evaluator7() external view returns (address) {
        return s.evaluator7;
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

    function updateEvaluator5(address _evaluator) external onlyOwner {
        GameConfigs.updateEvaluator5(_evaluator);

        emit UpdateEvaluator5(_evaluator);
    }

    function updateEvaluator7(address _evaluator) external onlyOwner {
        GameConfigs.updateEvaluator7(_evaluator);

        emit UpdateEvaluator7(_evaluator);
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
