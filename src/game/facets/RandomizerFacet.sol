// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { Player, Players } from "../models/Players.sol";
import { RandomizerRequest, RandomizerRequests, RequestAction } from "../models/RandomizerRequests.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract RandomizerFacet is BaseFacet, IRandomizerCallback {
    using Attacks for Attack_;
    using Players for Player;
    using Cards for Card;

    error Forbidden();
    error InvalidRandomizerId();

    function pendingRandomizerRequest(uint256 id) external view returns (RandomizerRequest memory) {
        return s.pendingRandomizerRequests[id];
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != s.randomizer) revert Forbidden();

        RandomizerRequest memory request = s.pendingRandomizerRequests[randomizerId];
        delete s.pendingRandomizerRequests[randomizerId];

        if (request.action == RequestAction.Attack) {
            Attack_ storage a = Attacks.get(request.id);

            Players.get(a.attacker).checkpoint();
            Players.get(a.defender).checkpoint();

            a.determineAttackResult(value);
            a.finalize();
        } else {
            revert InvalidRandomizerId();
        }
    }
}
