// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFacet {
    function selectors() external view returns (bytes4[] memory);
}
