// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Attack_, GameStorage, RandomizerRequest, RequestAction } from "../GameStorage.sol";
import { Attacks } from "../models/Attacks.sol";
import { IRandomizer } from "src/interfaces/IRandomizer.sol";

library RandomizerRequests {
    using Attacks for Attack_;

    error InsufficientFee();
    error InvalidAction();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function request(RequestAction action, uint256 id) internal returns (uint256 randomizerId) {
        GameStorage storage s = gameStorage();

        if (action == RequestAction.Attack) {
            if (s.staging) {
                // use psuedo-random value in staging env
                bytes32 value = keccak256(abi.encodePacked(id, block.number, block.timestamp));
                Attacks.get(id).onResolve(value);
            } else {
                address _randomizer = s.randomizer;
                uint256 _randomizerGasLimit = s.randomizerGasLimit;
                uint256 fee = IRandomizer(_randomizer).estimateFee(_randomizerGasLimit);
                if (address(this).balance < fee) revert InsufficientFee();

                IRandomizer(_randomizer).clientDeposit{ value: fee }(address(this));
                randomizerId = IRandomizer(_randomizer).request(_randomizerGasLimit);
                s.pendingRandomizerRequests[randomizerId] = RandomizerRequest(action, id);
            }
        } else {
            revert InvalidAction();
        }
    }
}
