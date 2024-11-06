// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Card, GameStorage, Player } from "../GameStorage.sol";
import { isValidUsername } from "../utils/StringUtils.sol";
import { Cards } from "./Cards.sol";
import { GameConfig, GameConfigs } from "./GameConfigs.sol";
import { Random } from "./Random.sol";
import { Rewards } from "./Rewards.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { ArrayLib } from "src/libraries/ArrayLib.sol";

library Players {
    using ArrayLib for uint256[];
    using Cards for Card;

    event CreatePlayer(address indexed account);
    event PlayerGainXP(address indexed account, uint32 xp);
    event PlayerLevelUp(address indexed account, uint8 level);
    event IncrementCards(address indexed account);
    event DecrementCards(address indexed account);
    event IncrementPoints(address indexed account, uint256 points);
    event DecrementPoints(address indexed account, uint256 points);
    event IncrementShares(address indexed account, uint256 shares);
    event DecrementShares(address indexed account, uint256 shares);
    event UpdateUsername(address indexed account, bytes32 indexed username);
    event UpdateAvatar(address indexed account, uint256 tokenId);
    event AddIncomingAttack(address indexed account, uint256 attackId);
    event RemoveIncomingAttack(address indexed account, uint256 attackId);
    event AddOutgoingAttack(address indexed account, uint256 attackId);
    event RemoveOutgoingAttack(address indexed account, uint256 attackId);
    event DebugCheckpointPlayer(
        address indexed account, uint256 shares, uint256 accRewardPerShare, uint256 rewardDebt, uint256 accReward
    );
    event CheckpointPlayer(address indexed account);

    error NotPlayer();
    error PlayerInitialized();
    error Forbidden();
    error InvalidUsername();
    error DuplicateUsername();
    error ExceedingMaxAttacks();
    error ExceedingMaxCards();
    error AlreadyUnderAttack();
    error InsufficientCards();
    error InsufficientPoints();
    error InsufficientItems();
    error InsufficientShares();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function maxXP(uint8 level) internal pure returns (uint32 xp) {
        return 3000 * level * level;
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
        self.level = 1;
        self.maxCards = 5;
        self.avatarTokenId = type(uint256).max;
        updateUsername(self, username);

        emit CreatePlayer(account);
        emit PlayerLevelUp(account, 1);
    }

    function initialized(Player storage self) internal view returns (bool) {
        return self.account != address(0);
    }

    function assertNotInitialized(Player storage self) internal view {
        if (initialized(self)) revert PlayerInitialized();
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

    function updateAvatar(Player storage self, uint256 tokenId) internal {
        Card storage card = Cards.get(tokenId);
        if (card.owner != msg.sender) revert Forbidden();

        self.avatarTokenId = tokenId;

        emit UpdateAvatar(self.account, tokenId);
    }

    function updateLastDefendedAt(Player storage self) internal {
        self.lastDefendedAt = uint64(block.timestamp);
    }

    function removeAvatar(Player storage self) internal {
        self.avatarTokenId = type(uint256).max;

        emit UpdateAvatar(self.account, type(uint256).max);
    }

    function addIncomingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        if (s.incomingAttackIds[account].length >= self.maxCards / 2) revert ExceedingMaxAttacks();

        s.incomingAttackIds[account].push(attackId);

        emit AddIncomingAttack(account, attackId);
    }

    function removeIncomingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        s.incomingAttackIds[account].remove(attackId);

        emit RemoveIncomingAttack(account, attackId);
    }

    function addOutgoingAttack(Player storage self, uint256 attackId) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
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

    function increaseBogoRandomly(Player storage self) internal {
        if (self.hasAttacked) {
            if (Random.draw(0, 100) < GameConfigs.latest().bogoPercentage) {
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
        if (self.cards >= self.maxCards) revert ExceedingMaxCards();

        uint256 cards = self.cards + 1;
        self.cards = cards;

        emit IncrementCards(self.account);
    }

    function decrementCards(Player storage self) internal {
        if (self.cards < 1) revert InsufficientCards();

        uint256 cards = self.cards - 1;
        self.cards = cards;

        emit DecrementCards(self.account);
    }

    function incrementPoints(Player storage self, uint256 points) internal {
        uint256 newPoints = self.points + points;
        self.points = newPoints;

        emit IncrementPoints(self.account, points);
    }

    function decrementPoints(Player storage self, uint256 points) internal {
        if (points > self.points) revert InsufficientPoints();

        uint256 newPoints = self.points - points;
        self.points = newPoints;

        emit DecrementPoints(self.account, points);
    }

    function incrementShares(Player storage self, uint256 shares) internal {
        GameStorage storage s = gameStorage();

        address account = self.account;
        uint256 sharesSum = s.sharesSum + shares;
        uint256 _shares = s.shares[account] + shares;
        s.sharesSum = sharesSum;
        s.shares[account] = _shares;
        s.rewardDebt[account] = _shares * s.accRewardPerShare / 1e12;

        emit IncrementShares(account, shares);
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

        emit DecrementShares(account, shares);
    }

    function gainXP(Player storage self, uint32 delta) internal {
        GameConfig memory c = GameConfigs.latest();
        uint8 maxLevel = c.maxPlayerLevel;
        uint8 level = self.level;
        uint32 xp = self.xp;
        address account = self.account;

        emit PlayerGainXP(account, delta);

        while (level < maxLevel) {
            uint32 max = maxXP(level);
            if (xp + delta >= max) {
                delta -= (max - xp);
                level += 1;
                xp = 0;

                emit PlayerLevelUp(account, level);
            } else {
                xp += delta;
                break;
            }
        }
        self.level = level;
        self.xp = xp;
        self.maxCards = 4 + level;
    }

    function checkpoint(Player storage self) internal {
        Rewards.checkpoint();

        GameStorage storage s = gameStorage();

        address account = self.account;
        uint256 shares = s.shares[account];
        if (shares > 0) {
            s.accReward[account] += shares * s.accRewardPerShare / 1e12 - s.rewardDebt[account];
        }

        emit DebugCheckpointPlayer(account, shares, s.accRewardPerShare, s.rewardDebt[account], s.accReward[account]);
        emit CheckpointPlayer(account);
    }
}
