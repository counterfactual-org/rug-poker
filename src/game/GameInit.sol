// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "diamond/interfaces/IERC165.sol";
import { IERC173 } from "diamond/interfaces/IERC173.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";

import { GameConfig, GameStorage } from "./GameStorage.sol";
import { GameConfigs } from "./models/GameConfigs.sol";

contract GameInit {
    function init(
        bool staging,
        address nft,
        address randomizer,
        address evaluator9,
        address treasury,
        uint256 randomizerGasLimit,
        GameConfig memory c
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[0xd9b67a26] = true; // ERC165 Interface ID for ERC1155
        ds.supportedInterfaces[0x0e89341c] = true; // ERC165 Interface ID for ERC1155MetadataURI

        GameStorage storage s = GameConfigs.gameStorage();
        s.staging = staging;
        s.nft = nft;
        s.randomizer = randomizer;
        GameConfigs.updateEvaluator9(evaluator9);
        GameConfigs.updateTreasury(treasury);
        GameConfigs.updateRandomizerGasLimit(randomizerGasLimit);
        GameConfigs.updateConfig(c);
    }
}
