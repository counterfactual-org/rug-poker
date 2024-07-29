// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App, Config } from "../App.sol";

import { MIN_RANDOMIZER_GAS_LIMIT } from "../Constants.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract ConfigsFacet is BaseFacet {
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
        return App.config();
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) external onlyOwner {
        App.updateRandomizerGasLimit(_randomizerGasLimit);
    }

    function updateEvaluator(address _evaluator) external onlyOwner {
        App.updateEvaluator(_evaluator);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        App.updateTreasury(_treasury);
    }

    function updateConfig(Config memory c) external {
        App.updateConfig(c);
    }
}
