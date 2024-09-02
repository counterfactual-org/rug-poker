// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Player, Players } from "../models/Players.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseGameFacet } from "./BaseGameFacet.sol";

contract PlayersFacet is BaseGameFacet {
    using Players for Player;

    error ExistentPlayer();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = this.getPlayer.selector;
        s[1] = this.accRewardOf.selector;
        s[2] = this.sharesSum.selector;
        s[3] = this.sharesOf.selector;
        s[4] = this.createPlayer.selector;
        s[5] = this.checkpointPlayer.selector;
        s[6] = this.checkpoint.selector;
    }

    function getPlayer(address account) external view returns (Player memory) {
        return Players.getOrRevert(account);
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

    function createPlayer(bytes32 username) external {
        Player storage player = Players.get(msg.sender);
        if (player.initialized()) revert ExistentPlayer();
        player = Players.init(msg.sender, username);
    }

    function checkpointPlayer(address account) external {
        Players.get(account).checkpoint();
    }

    function checkpoint() external {
        Rewards.checkpoint();
    }
}
