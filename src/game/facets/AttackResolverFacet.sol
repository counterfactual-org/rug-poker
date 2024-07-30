// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Attack_, Attacks } from "../models/Attacks.sol";
import { Randomizers } from "../models/Randomizers.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract AttckResolverFacet is BaseFacet, IRandomizerCallback {
    using Attacks for Attack_;

    error Forbidden();

    function pendingRandomizerRequest(uint256 id) external view returns (uint256 attackId) {
        return Randomizers.pendingRequest(id);
    }

    function resolveAttack(uint256 attackId) external payable {
        Attacks.get(attackId).resolve();
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != s.randomizer) revert Forbidden();

        uint256 attackId = Randomizers.getPendingRequest(randomizerId);
        Attacks.get(attackId).onFinalize(value);
    }
}
