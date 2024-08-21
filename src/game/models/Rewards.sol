// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { GameStorage } from "../GameStorage.sol";
import { GameConfigs } from "./GameConfigs.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

library Rewards {
    event MoveAccReward(address indexed from, address indexed to, uint256 amount);
    event ClaimReward(address indexed account, uint256 amount);
    event Checkpoint(uint256 accRewardPerShare, uint256 reserve);

    error ExceedingShares();

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

    function moveAccReward(address from, address to, uint8 percentage) internal {
        GameStorage storage s = gameStorage();

        uint256 reward = s.accReward[from];
        uint256 amount = reward * percentage / 100;

        uint256 fee = amount / 10;
        s.accReward[from] = reward - amount;
        s.accReward[to] += amount - fee;

        TransferLib.transferETH(s.treasury, fee, address(0));

        emit MoveAccReward(from, to, amount);
    }

    function claim(address owner, uint256 shares) internal {
        GameStorage storage s = gameStorage();

        uint256 ownerShares = s.shares[owner];
        if (shares > ownerShares) revert ExceedingShares();

        uint256 acc = s.accReward[owner];
        uint256 reward = acc * shares / ownerShares;

        s.accReward[owner] = acc - reward;
        s.reserve -= reward;

        TransferLib.transferETH(owner, reward, address(0));

        emit ClaimReward(owner, reward);
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
