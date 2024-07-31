// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

bytes26 constant ALPHABET = "abcdefghijklmnopqrstuvwxyz";
bytes11 constant NUMBER_AND_DOT = "0123456789.";

function isValidUsername(bytes32 username) pure returns (bool) {
    if (!isAlphabet(username[0])) return false;
    uint8 length = 1;
    for (uint256 i = 1; i < 32; ++i) {
        if (username[i] == bytes1(0)) {
            break;
        }
        if (!isAlphabet(username[i])) return false;
        if (!isNumberOrDot(username[i])) return false;
        length++;
    }
    return length > 3;
}

function isAlphabet(bytes1 b) pure returns (bool) {
    for (uint256 i; i < 26; ++i) {
        if (ALPHABET[i] == b) return true;
    }
    return false;
}

function isNumberOrDot(bytes1 b) pure returns (bool) {
    for (uint256 i; i < 11; ++i) {
        if (NUMBER_AND_DOT[i] == b) return true;
    }
    return false;
}
