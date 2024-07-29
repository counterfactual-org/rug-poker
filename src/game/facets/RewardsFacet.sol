// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { App, Config } from "../App.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract RewardsFacet is BaseFacet {
    event ClaimReward(address indexed account, uint256 amount);

    error NoClaimableReward();

    function claimableRewardOf(address account) external view returns (uint256) {
        return s.claimableRewardOf[account];
    }

    function accRewardOf(address account) external view returns (uint256) {
        uint256 _accRewardPerShare = App.getAccRewardPerShare(address(this).balance);
        return s.accReward[account] + s.sharesOf[account] * _accRewardPerShare / 1e12 - s.rewardDebt[account];
    }

    function claimReward() external {
        uint256 reward = s.claimableRewardOf[msg.sender];
        if (reward == 0) revert NoClaimableReward();

        s.claimableRewardOf[msg.sender] = 0;

        TransferLib.transferETH(msg.sender, reward, address(0));

        emit ClaimReward(msg.sender, reward);
    }
}
