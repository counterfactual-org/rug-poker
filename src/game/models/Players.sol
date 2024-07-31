// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Card, GameStorage, Player } from "../GameStorage.sol";
import { isValidUsername } from "../utils/StringUtils.sol";
import { Cards } from "./Cards.sol";
import { Configs } from "./Configs.sol";
import { Rewards } from "./Rewards.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";

library Players {
    using Cards for Card;

    event AdjustShares(address indexed account, uint256 sharesSum, uint256 shares);
    event UpdateUsername(address indexed account, bytes32 indexed username);
    event UpdateIncomingAttack(address indexed account, uint256 attackId);
    event AddOutgoingAttack(address indexed account, uint256 attackId);
    event CheckpointPlayer(address indexed account);

    error InvalidUsername();
    error DuplicateUsername();
    error InsufficientFee();
    error AlreadyUnderAttack();
    error AttackingMax();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function get(address account) internal view returns (Player storage self) {
        return gameStorage().players[account];
    }

    function init(address account, bytes32 username) internal returns (Player storage self) {
        self = get(account);
        self.account = account;
        updateUsername(self, username);
    }

    function initialized(Player storage self) internal view returns (bool) {
        return self.account != address(0);
    }

    function isImmune(Player storage self) internal view returns (bool) {
        uint256 lastDefendedAt = self.lastDefendedAt;
        return lastDefendedAt > 0 && block.timestamp < lastDefendedAt + Configs.latest().immunePeriod;
    }

    function updateUsername(Player storage self, bytes32 username) internal {
        GameStorage storage s = gameStorage();
        if (!isValidUsername(username)) revert InvalidUsername();
        if (s.usernames[username] != address(0)) revert DuplicateUsername();

        address account = self.account;
        s.usernames[username] = account;
        self.username = username;

        emit UpdateUsername(account, username);
    }

    function updateLastDefendedAt(Player storage self) internal {
        self.lastDefendedAt = uint64(block.timestamp);
    }

    function updateIncomingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        if (s.incomingAttackId[account] > 0) revert AlreadyUnderAttack();

        s.incomingAttackId[account] = attackId;

        emit UpdateIncomingAttack(account, attackId);
    }

    function addOutgoingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        if (s.outgoingAttackIds[account].length >= Configs.latest().maxAttacks) revert AttackingMax();

        s.outgoingAttackIds[account].push(attackId);

        emit AddOutgoingAttack(account, attackId);
    }

    function increaseFreeMintingIfHasNotPlayed(Player storage self) internal {
        if (!self.hasPlayed) {
            address minter = INFT(gameStorage().nft).minter();
            INFTMinter(minter).increaseFreeMintingOf(self.account);
            self.hasPlayed = true;
        }
    }

    function increaseFreeMintingIfHasNotAttacked(Player storage self, address defender) internal {
        GameStorage storage s = gameStorage();
        if (!s.hasAttacked[self.account][defender]) {
            address nftMinter = INFT(s.nft).minter();
            INFTMinter(nftMinter).increaseFreeMintingOf(self.account);
            s.hasAttacked[self.account][defender] = true;
        }
    }

    function incrementCards(Player storage self) internal {
        self.cards += 1;
    }

    function decrementCards(Player storage self) internal {
        self.cards -= 1;
    }

    function incrementShares(Player storage self, uint256 shares) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        uint256 sharesSum = s.sharesSum + shares;
        uint256 _shares = s.shares[account] + shares;
        s.sharesSum = sharesSum;
        s.shares[account] = _shares;
        s.rewardDebt[account] = _shares * s.accRewardPerShare / 1e12;

        emit AdjustShares(account, sharesSum, _shares);
    }

    function decrementShares(Player storage self, uint256 shares) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        uint256 sharesSum = s.sharesSum - shares;
        uint256 _shares = s.shares[account] - shares;
        s.sharesSum = sharesSum;
        s.shares[account] = _shares;
        s.rewardDebt[account] = _shares * s.accRewardPerShare / 1e12;

        emit AdjustShares(account, sharesSum, _shares);
    }

    function deductFee(Player storage self, uint8 bootyTier) internal returns (uint256 fee) {
        GameStorage storage s = gameStorage();
        uint256 acc = s.accReward[self.account];
        fee = Configs.latest().attackFees[bootyTier];
        if (acc < fee) revert InsufficientFee();
        s.accReward[self.account] = acc - fee;
    }

    function checkpoint(Player storage self) internal {
        Rewards.checkpoint();

        GameStorage storage s = gameStorage();

        address account = self.account;
        uint256 shares = s.shares[account];
        if (shares > 0) {
            s.accReward[account] += shares * s.accRewardPerShare / 1e12 - s.rewardDebt[account];
        }

        emit CheckpointPlayer(account);
    }
}
