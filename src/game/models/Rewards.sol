// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameStorage } from "../GameStorage.sol";

library Rewards {
    event Checkpoint(uint256 accRewardPerShare, uint256 reserve);

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function getAccRewardPerShare(uint256 balance) internal view returns (uint256 accRewardPerShare) {
        GameStorage storage s = gameStorage();

        accRewardPerShare = s.accRewardPerShare;
        if (balance > s.reserve) {
            uint256 shares = s.sharesSum;
            if (shares > 0) {
                uint256 newReward = balance - s.reserve;
                accRewardPerShare += newReward * 1e12 / shares;
            }
        }
    }

    function moveBooty(address attacker, address defender, uint8 bootyPercentage) internal {
        GameStorage storage s = gameStorage();

        uint256 reward = s.accReward[defender];
        uint256 booty = reward * bootyPercentage / 100;

        s.accReward[attacker] += booty;
        s.accReward[defender] = reward - booty;
    }

    function claim(address owner, uint256 shares) internal {
        GameStorage storage s = gameStorage();

        uint256 acc = s.accReward[owner];
        uint256 reward = acc * shares / s.shares[owner];

        s.accReward[owner] = acc - reward;
        s.claimableReward[owner] += reward;
    }

    function checkpoint() internal {
        GameStorage storage s = gameStorage();

        uint256 _reserve = address(this).balance;
        uint256 _accRewardPerShare = getAccRewardPerShare(_reserve);
        s.accRewardPerShare = _accRewardPerShare;
        s.reserve = _reserve;

        emit Checkpoint(_accRewardPerShare, _reserve);
    }
}