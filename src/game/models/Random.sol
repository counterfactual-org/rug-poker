// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameStorage, RandomValue } from "../GameStorage.sol";

library Random {
    error InvalidMinMax();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function set(bytes32 seed) internal returns (RandomValue storage random) {
        GameStorage storage s = gameStorage();
        s.random = RandomValue(keccak256(abi.encodePacked(seed, block.number, block.timestamp)), 0);
        return s.random;
    }

    function draw(uint8 min, uint8 max) internal returns (uint8 value) {
        if (max <= min) revert InvalidMinMax();

        RandomValue storage random = gameStorage().random;
        uint256 offset = random.offset;
        value = min + uint8(random.seed[offset]) % (max - min);
        random.offset = (offset + 1) % 32;
    }
}
