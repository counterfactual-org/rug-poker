// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameStorage } from "../GameStorage.sol";
import { IRandomizer } from "src/interfaces/IRandomizer.sol";

library Randomizers {
    error InsufficientFee();
    error InvalidRandomizerId();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function pendingRequest(uint256 id) external view returns (uint256 attackId) {
        return gameStorage().pendingRandomizerRequests[id];
    }

    function request(address client, uint256 attackId) internal returns (uint256 randomizerId) {
        GameStorage storage s = gameStorage();

        address _randomizer = s.randomizer;
        uint256 _randomizerGasLimit = s.randomizerGasLimit;
        uint256 fee = IRandomizer(_randomizer).estimateFee(_randomizerGasLimit);
        if (client.balance < fee) revert InsufficientFee();

        IRandomizer(_randomizer).clientDeposit{ value: fee }(client);
        randomizerId = IRandomizer(_randomizer).request(_randomizerGasLimit);
        s.pendingRandomizerRequests[randomizerId] = attackId;
    }

    function getPendingRequest(uint256 randomizerId) internal returns (uint256 attackId) {
        GameStorage storage s = gameStorage();

        attackId = s.pendingRandomizerRequests[randomizerId];
        if (attackId == 0) revert InvalidRandomizerId();
        delete s.pendingRandomizerRequests[randomizerId];
    }
}
