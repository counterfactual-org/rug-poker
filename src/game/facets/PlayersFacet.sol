// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Player, Players } from "../models/Players.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseFacet } from "./BaseFacet.sol";

contract PlayersFacet is BaseFacet {
    using Players for Player;

    function getPlayer(address account) external view returns (Player memory) {
        return Players.get(account);
    }

    function accRewardOf(address account) external view returns (uint256) {
        uint256 _accRewardPerShare = Rewards.getAccRewardPerShare(address(this).balance);
        return s.accReward[account] + s.shares[account] * _accRewardPerShare / 1e12 - s.rewardDebt[account];
    }

    function sharesSum() external view returns (uint256) {
        return s.sharesSum;
    }

    function sharesOf(address account) external view returns (uint256) {
        return s.shares[account];
    }

    function updatePlayer(bytes32 username) external {
        Player storage player = Players.get(msg.sender);
        if (player.initialized()) {
            player.updateUsername(username);
        } else {
            player = Players.init(msg.sender, username);
        }
    }

    function checkpointPlayer(address account) external {
        Players.get(account).checkpoint();
    }

    function checkpoint() external {
        Rewards.checkpoint();
    }
}
