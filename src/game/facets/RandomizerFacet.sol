// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Attack_, Attacks } from "../models/Attacks.sol";
import { Card, Cards } from "../models/Cards.sol";
import { Player, Players } from "../models/Players.sol";
import { RandomizerRequest, RandomizerRequests, RequestAction } from "../models/RandomizerRequests.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract RandomizerFacet is BaseGameFacet, IRandomizerCallback {
    using Attacks for Attack_;
    using Players for Player;
    using Cards for Card;

    error Forbidden();
    error InvalidRandomizerId();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = this.pendingRandomizerRequest.selector;
        s[1] = this.randomizerCallback.selector;
    }

    function pendingRandomizerRequest(uint256 id) external view returns (RandomizerRequest memory) {
        return s.pendingRandomizerRequests[id];
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != s.randomizer) revert Forbidden();

        RandomizerRequest memory request = s.pendingRandomizerRequests[randomizerId];
        delete s.pendingRandomizerRequests[randomizerId];

        if (request.action == RequestAction.Attack) {
            Attack_ storage attack = Attacks.get(request.id);
            Player storage attacker = Players.get(attack.attacker);

            attacker.checkpoint();
            attacker.increaseBogoRandomly(value);
            Players.get(attack.defender).checkpoint();

            attack.determineAttackResult(value);
            attack.finalize();
        } else {
            revert InvalidRandomizerId();
        }
    }
}
