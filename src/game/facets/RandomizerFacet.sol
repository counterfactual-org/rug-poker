// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { RandomizerRequest, RandomizerRequests } from "../models/RandomizerRequests.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract RandomizerFacet is BaseGameFacet, IRandomizerCallback {
    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = this.pendingRandomizerRequest.selector;
        s[1] = this.randomizerCallback.selector;
    }

    function pendingRandomizerRequest(uint256 id) external view returns (RandomizerRequest memory) {
        return s.pendingRandomizerRequests[id];
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        RandomizerRequests.onCallback(randomizerId, value);
    }
}
