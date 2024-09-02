// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Attack_, Card, GameStorage, RandomizerRequest, RequestAction } from "../GameStorage.sol";
import { Attacks } from "../models/Attacks.sol";
import { Cards } from "../models/Cards.sol";
import { Player, Players } from "../models/Players.sol";
import { Random } from "../models/Random.sol";
import { IRandomizer } from "src/interfaces/IRandomizer.sol";

library RandomizerRequests {
    using Attacks for Attack_;
    using Players for Player;
    using Cards for Card;

    error InsufficientFee();
    error InvalidAction();
    error Forbidden();
    error InvalidRandomizerId();

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
                Random.set(keccak256(abi.encodePacked(id, block.number, block.timestamp)));
                Attacks.get(id).onResolve();
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

    function onCallback(uint256 randomizerId, bytes32 value) internal {
        GameStorage storage s = gameStorage();

        if (msg.sender != s.randomizer) revert Forbidden();

        RandomizerRequest memory r = s.pendingRandomizerRequests[randomizerId];
        delete s.pendingRandomizerRequests[randomizerId];

        Random.set(value);

        if (r.action == RequestAction.Attack) {
            Attacks.get(r.id).onResolve();
        } else {
            revert InvalidRandomizerId();
        }
    }
}
