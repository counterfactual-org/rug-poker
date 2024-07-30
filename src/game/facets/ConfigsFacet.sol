// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Config, Configs } from "../models/Configs.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract ConfigsFacet is BaseFacet {
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

    function config() external view returns (Config memory) {
        return Configs.latest();
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) external onlyOwner {
        Configs.updateRandomizerGasLimit(_randomizerGasLimit);

        emit UpdateRandomizerGasLimit(_randomizerGasLimit);
    }

    function updateEvaluator(address _evaluator) external onlyOwner {
        Configs.updateEvaluator(_evaluator);

        emit UpdateEvaluator(_evaluator);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        Configs.updateTreasury(_treasury);

        emit UpdateTreasury(_treasury);
    }

    function updateConfig(Config memory c) external {
        Configs.updateConfig(c);

        emit UpdateConfig();
    }
}
