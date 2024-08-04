// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Player, Players } from "../models/Players.sol";
import { Rewards } from "../models/Rewards.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract RewardsFacet is BaseFacet {
    using Players for Player;

    event ClaimReward(address indexed account, uint256 amount);

    error NoClaimableReward();

    function claimableRewardOf(address account) external view returns (uint256) {
        return s.claimableReward[account];
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

    function claimReward() external {
        uint256 reward = s.claimableReward[msg.sender];
        if (reward == 0) revert NoClaimableReward();

        s.claimableReward[msg.sender] = 0;
        s.reserve -= reward;

        TransferLib.transferETH(msg.sender, reward, address(0));

        emit ClaimReward(msg.sender, reward);
    }

    function checkpointPlayer(address account) external {
        Players.get(account).checkpoint();
    }

    function checkpoint() external {
        Rewards.checkpoint();
    }
}
