// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App } from "../App.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract CheckpointsFacet is BaseFacet {
    function checkpointUser(address account) external {
        App.checkpointUser(account);
    }

    function checkpoint() external {
        App.checkpoint();
    }
}
