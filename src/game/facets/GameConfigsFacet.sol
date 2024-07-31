// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract GameConfigsFacet is BaseFacet {
    event UpdateRandomizerGasLimit(uint256 gasLimit);
    event UpdateEvaluator(address indexed evaluator);
    event UpdateTreasury(address indexed treasury);
    event UpdateConfig();

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
