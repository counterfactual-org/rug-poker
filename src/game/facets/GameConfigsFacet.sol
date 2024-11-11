// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameConfig, GameConfigs } from "../models/GameConfigs.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract GameConfigsFacet is BaseGameFacet {
    event UpdateEvaluator9(address indexed evaluator);
    event UpdateTreasury(address indexed treasury);
    event UpdateConfig();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = this.nft.selector;
        s[1] = this.evaluator9.selector;
        s[2] = this.treasury.selector;
        s[3] = this.config.selector;
        s[4] = this.updateEvaluator9.selector;
        s[5] = this.updateTreasury.selector;
        s[6] = this.updateConfig.selector;
    }

    function nft() external view returns (address) {
        return s.nft;
    }

    function evaluator9() external view returns (address) {
        return s.evaluator9;
    }

    function treasury() external view returns (address) {
        return s.treasury;
    }

    function config() external view returns (GameConfig memory) {
        return GameConfigs.latest();
    }

    function updateEvaluator9(address _evaluator) external onlyOwner {
        GameConfigs.updateEvaluator9(_evaluator);

        emit UpdateEvaluator9(_evaluator);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        GameConfigs.updateTreasury(_treasury);

        emit UpdateTreasury(_treasury);
    }

    function updateConfig(GameConfig memory c) external onlyOwner {
        GameConfigs.updateConfig(c);

        emit UpdateConfig();
    }
}
