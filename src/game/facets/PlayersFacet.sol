// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Player, Players } from "../models/Players.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract PlayersFacet is BaseFacet {
    using Players for Player;

    error AlreadyPlayer();

    function updatePlayer(bytes32 username) external {
        Player storage player = Players.get(msg.sender);
        if (player.initialized()) {
            player.updateUsername(username);
        } else {
            player = Players.init(msg.sender, username);
        }
    }
}
