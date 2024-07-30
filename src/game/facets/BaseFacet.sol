// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameStorage } from "../GameStorage.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";

abstract contract BaseFacet {
    GameStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}
