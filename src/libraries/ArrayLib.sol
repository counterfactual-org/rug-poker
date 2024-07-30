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

    function hasDuplicate(uint256[5] memory array) internal pure returns (bool) {
        for (uint256 i; i < 5 - 1; ++i) {
            for (uint256 j = i + 1; j < 5; ++j) {
                if (array[i] == array[j]) return true;
            }
        }
        return false;
    }
}
