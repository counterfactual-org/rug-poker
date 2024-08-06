// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS } from "./GameConstants.sol";

struct GameStorage {
    // configs
    address nft;
    address randomizer;
    address evaluator;
    uint256 randomizerGasLimit;
    address treasury;
    uint256 configVersion;
    mapping(uint256 version => GameConfig) configs;
    mapping(uint256 itemId => ItemEntry) itemEntries;
    // rewards
    uint256 reserve;
    uint256 accRewardPerShare;
    mapping(address account => uint256) accReward;
    uint256 sharesSum;
    mapping(address account => uint256) shares;
    mapping(address account => uint256) rewardDebt;
    // players
    mapping(bytes32 username => address) usernames;
    mapping(address account => Player) players;
    mapping(address account => uint256) incomingAttackId;
    mapping(address account => uint256[]) outgoingAttackIds;
    // cards
    mapping(uint256 tokenId => Card) cards;
    // attacks
    uint256 lastAttackId;
    mapping(uint256 attackId => Attack_) attacks;
    mapping(uint256 attackId => uint256[HOLE_CARDS]) attackingTokenIds;
    mapping(uint256 attackId => uint256[HOLE_CARDS]) defendingTokenIds;
    mapping(uint256 attackId => uint8[]) defendingJokerCards;
    // randomizer requests
    mapping(uint256 randomizerId => RandomizerRequest) pendingRandomizerRequests;
}

struct GameConfig {
    uint8 maxCards;
    uint8 maxJokers;
    uint8 maxAttacks;
    uint8 minBootyPercentage;
    uint8 maxBootyPercentage;
    uint8 maxBootyCards;
    uint8 minDurability;
    uint8 maxDurability;
    uint8 maxLevel;
    uint8 bogoPercentage;
    uint32 minDuration;
    uint32 immunePeriod;
    uint32 attackPeriod;
}

struct ItemEntry {
    uint256 id;
    string name;
    string description;
    string image;
    uint256 points;
    uint256 eth;
}

struct Player {
    address account;
    bool hasPlayed;
    bool hasAttacked;
    uint64 lastDefendedAt;
    bytes32 username;
    uint256 cards;
    uint256 points;
}

struct Card {
    uint256 tokenId;
    address owner;
    uint8 durability;
    uint8 rank;
    uint8 suit;
    uint8 level;
    uint32 xp;
    bool underuse;
    uint64 lastAddedAt;
}

struct Attack_ {
    uint256 id;
    bool resolving;
    bool finalized;
    AttackResult result;
    uint8 level;
    address attacker;
    address defender;
    uint64 startedAt;
}

enum AttackResult {
    None,
    Success,
    Fail,
    Draw
}

struct RandomizerRequest {
    RequestAction action;
    uint256 id;
}

enum RequestAction {
    Invalid,
    Attack
}
