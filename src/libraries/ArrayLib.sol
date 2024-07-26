// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ArrayLib {
    function remove(uint256[] storage array, uint256 value) internal {
        uint256 length = array.length;
        for (uint256 i; i < length; ++i) {
            if (array[i] == value) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
    }
}
