// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterStorage } from "../MinterStorage.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";

abstract contract BaseFacet {
    MinterStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}
