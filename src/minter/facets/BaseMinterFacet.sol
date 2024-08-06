// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterStorage } from "../MinterStorage.sol";
import { LibDiamond } from "diamond/libraries/LibDiamond.sol";
import { IFacet } from "src/interfaces/IFacet.sol";

abstract contract BaseMinterFacet is IFacet {
    MinterStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    function selectors() external pure virtual returns (bytes4[] memory);
}
