// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameStorage } from "../GameStorage.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";
import { IFacet } from "src/interfaces/IFacet.sol";

abstract contract BaseGameFacet is IFacet {
    GameStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}
