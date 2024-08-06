// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Card, GameStorage, Player } from "../GameStorage.sol";
import { isValidUsername } from "../utils/StringUtils.sol";
import { Cards } from "./Cards.sol";
import { GameConfigs } from "./GameConfigs.sol";
import { Rewards } from "./Rewards.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { ArrayLib } from "src/libraries/ArrayLib.sol";

library Players {
    using ArrayLib for uint256[];
    using Cards for Card;

    event AdjustCards(address indexed account, uint256 cards);
    event AdjustPoints(address indexed account, uint256 points);
    event AdjustShares(address indexed account, uint256 sharesSum, uint256 shares);
    event UpdateUsername(address indexed account, bytes32 indexed username);
    event UpdateIncomingAttack(address indexed account, uint256 attackId);
    event AddOutgoingAttack(address indexed account, uint256 attackId);
    event RemoveOutgoingAttack(address indexed account, uint256 attackId);
    event CheckpointPlayer(address indexed account);

    error NotPlayer();
    error InvalidUsername();
    error DuplicateUsername();
    error AlreadyUnderAttack();
    error AttackingMax();
    error InsufficientCards();
    error InsufficientPoints();
    error InsufficientItems();
    error InsufficientShares();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function getOrRevert(address account) internal view returns (Player storage self) {
        self = get(account);
        if (!initialized(self)) revert NotPlayer();
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
        return lastDefendedAt > 0 && block.timestamp < lastDefendedAt + GameConfigs.latest().immunePeriod;
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
        if (attackId > 0 && s.incomingAttackId[account] > 0) revert AlreadyUnderAttack();

        s.incomingAttackId[account] = attackId;

        emit UpdateIncomingAttack(account, attackId);
    }

    function addOutgoingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        if (s.outgoingAttackIds[account].length >= GameConfigs.latest().maxAttacks) revert AttackingMax();

        s.outgoingAttackIds[account].push(attackId);

        emit AddOutgoingAttack(account, attackId);
    }

    function removeOutgoingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        s.outgoingAttackIds[account].remove(attackId);

        emit RemoveOutgoingAttack(account, attackId);
    }

    function increaseBogoIfHasNotPlayed(Player storage self) internal {
        if (!self.hasPlayed) {
            increaseBogo(self);
            self.hasPlayed = true;
        }
    }

    function increaseBogoRandomly(Player storage self, bytes32 seed) internal {
        if (self.hasAttacked) {
            bytes32 random = keccak256(abi.encodePacked(seed, block.number, block.timestamp));
            if (uint8(random[uint256(random) % 32]) % 100 < GameConfigs.latest().bogoPercentage) {
                increaseBogo(self);
            }
        } else {
            increaseBogo(self);
            self.hasAttacked = true;
        }
    }

    function increaseBogo(Player storage self) internal {
        address minter = INFT(gameStorage().nft).minter();
        INFTMinter(minter).increaseBogoOf(self.account);
    }

    function incrementCards(Player storage self) internal {
        uint256 cards = self.cards + 1;
        self.cards = cards;

        emit AdjustCards(self.account, cards);
    }

    function decrementCards(Player storage self) internal {
        if (self.cards < 1) revert InsufficientCards();

        uint256 cards = self.cards - 1;
        self.cards = cards;

        emit AdjustCards(self.account, cards);
    }

    function incrementPoints(Player storage self, uint256 points) internal {
        uint256 newPoints = self.points + points;
        self.points = newPoints;

        emit AdjustPoints(self.account, newPoints);
    }

    function decrementPoints(Player storage self, uint256 points) internal {
        if (points > self.points) revert InsufficientPoints();

        uint256 newPoints = self.points - points;
        self.points = newPoints;

        emit AdjustPoints(self.account, newPoints);
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
        if (shares > s.shares[account]) revert InsufficientShares();

        uint256 sharesSum = s.sharesSum - shares;
        uint256 _shares = s.shares[account] - shares;
        s.sharesSum = sharesSum;
        s.shares[account] = _shares;
        s.rewardDebt[account] = _shares * s.accRewardPerShare / 1e12;

        emit AdjustShares(account, sharesSum, _shares);
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
