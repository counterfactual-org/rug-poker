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
    using Cards for Card;

    event RequestRandomizer(RequestAction indexed action, uint256 indexed id, uint256 indexed randomizerId);

    error InsufficientFee();
    error InvalidAction();
    error Forbidden();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function request(RequestAction action, uint256 id) internal returns (uint256 randomizerId) {
        GameStorage storage s = gameStorage();
        if (s.staging) {
            // use psuedo-random value in staging env
            Random.setSeed(keccak256(abi.encodePacked(id, block.number, block.timestamp)));

            emit RequestRandomizer(action, id, 0);

            _onCallback(action, id);
        } else if (
            action == RequestAction.Flop || action == RequestAction.ShowDown || action == RequestAction.RepairCard
                || action == RequestAction.JokerizeCard || action == RequestAction.MutateRank
                || action == RequestAction.MutateSuit
        ) {
            address _randomizer = s.randomizer;
            uint256 _randomizerGasLimit = s.randomizerGasLimit;
            uint256 fee = IRandomizer(_randomizer).estimateFee(_randomizerGasLimit);
            if (address(this).balance < fee) revert InsufficientFee();

            IRandomizer(_randomizer).clientDeposit{ value: fee }(address(this));
            randomizerId = IRandomizer(_randomizer).request(_randomizerGasLimit);
            s.pendingRandomizerRequests[randomizerId] = RandomizerRequest(action, id);

            emit RequestRandomizer(action, id, randomizerId);
        } else {
            revert InvalidAction();
        }
    }

    function onCallback(uint256 randomizerId, bytes32 value) internal {
        GameStorage storage s = gameStorage();

        if (msg.sender != s.randomizer) revert Forbidden();

        RandomizerRequest memory r = s.pendingRandomizerRequests[randomizerId];
        delete s.pendingRandomizerRequests[randomizerId];

        Random.setSeed(value);

        _onCallback(r.action, r.id);
    }

    function _onCallback(RequestAction action, uint256 id) private {
        if (action == RequestAction.Flop) {
            Attacks.getOrRevert(id).onFlop();
        } else if (action == RequestAction.ShowDown) {
            Attacks.getOrRevert(id).onShowDown();
        } else if (action == RequestAction.RepairCard) {
            Cards.getOrRevert(id).onRepair();
        } else if (action == RequestAction.JokerizeCard) {
            Cards.getOrRevert(id).onJokerize();
        } else if (action == RequestAction.MutateRank) {
            Cards.getOrRevert(id).onMutateRank();
        } else if (action == RequestAction.MutateSuit) {
            Cards.getOrRevert(id).onMutateSuit();
        } else {
            revert InvalidAction();
        }
    }
}
