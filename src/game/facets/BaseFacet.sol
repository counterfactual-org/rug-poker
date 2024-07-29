// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { AppStorage } from "../AppStorage.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";

abstract contract BaseFacet {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}
