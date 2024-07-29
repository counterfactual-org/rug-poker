// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "diamond/interfaces/IERC165.sol";
import { IERC173 } from "diamond/interfaces/IERC173.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";

import { App } from "./App.sol";
import { AppStorage, Config } from "./AppStorage.sol";

contract AppInit {
    function init(
        address nft,
        address randomizer,
        address evaluator,
        uint256 randomizerGasLimit,
        address treasury,
        Config memory c
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        AppStorage storage s = App.appStorage();
        s.nft = nft;
        s.randomizer = randomizer;
        App.updateEvaluator(evaluator);
        App.updateRandomizerGasLimit(randomizerGasLimit);
        App.updateTreasury(treasury);
        App.updateConfig(c);
    }
}
