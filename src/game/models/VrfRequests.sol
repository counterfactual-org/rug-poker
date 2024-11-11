// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Attack_, Card, GameStorage, RequestAction } from "../GameStorage.sol";
import { Attacks } from "../models/Attacks.sol";
import { Cards } from "../models/Cards.sol";
import { Player, Players } from "../models/Players.sol";
import { Random } from "../models/Random.sol";

library VrfRequests {
    using Attacks for Attack_;
    using Cards for Card;

    error InvalidAction();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function request(RequestAction action, uint256 id) internal {
        // TODO: turn on vrf later
        // use psuedo-random value in staging env
        Random.setSeed(keccak256(abi.encodePacked(id, block.number, block.timestamp)));

        _onCallback(action, id);
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
