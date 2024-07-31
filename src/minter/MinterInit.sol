// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "diamond/interfaces/IERC165.sol";
import { IERC173 } from "diamond/interfaces/IERC173.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";

import { MinterConfig, MinterStorage } from "./MinterStorage.sol";
import { MinterConfigs } from "./models/MinterConfigs.sol";

contract MinterInit {
    function init(address _nft, uint256 _tokensInBatch, address _treasury, address _game, MinterConfig memory c)
        external
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        MinterStorage storage s = MinterConfigs.minterStorage();
        s.nft = _nft;
        s.tokensInBatch = _tokensInBatch;
        MinterConfigs.updateTreasury(_treasury);
        MinterConfigs.updateGame(_game);
        MinterConfigs.updateConfig(c);
    }
}
