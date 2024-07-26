// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IRandomizerCallback {
    function randomizerCallback(uint256 id, bytes32 value) external;
}
