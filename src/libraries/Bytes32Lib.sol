// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Bytes32Lib {
    function setByte(bytes32 data, uint8 index, bytes1 b) internal pure returns (bytes32) {
        data &= ~(bytes32(bytes1(0xff)) << ((32 - index - 1) * 8));
        data |= bytes32(b) << ((32 - index - 1) * 8);
        return data;
    }
}
