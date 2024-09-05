// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ATTACK_ROUNDS } from "./GameConstants.sol";

struct GameStorage {
    // configs
    bool staging;
    address nft;
    address randomizer;
    address evaluator5;
    address evaluator7;
    uint256 randomizerGasLimit;
    address treasury;
    uint256 configVersion;
    mapping(uint256 version => GameConfig) configs;
    // items
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
    mapping(address account => uint256[]) incomingAttackIds;
    mapping(address account => uint256[]) outgoingAttackIds;
    // cards
    mapping(uint256 tokenId => Card) cards;
    // attacks
    uint256 lastAttackId;
    mapping(uint256 attackId => Attack_) attacks;
    mapping(uint256 attackId => uint256[]) attackingTokenIds;
    mapping(uint256 attackId => uint256[]) defendingTokenIds;
    mapping(uint256 attackId => uint8[]) attackingJokerCards;
    mapping(uint256 attackId => uint8[]) defendingJokerCards;
    mapping(uint256 attackId => uint8[][ATTACK_ROUNDS]) communityCards;
    // randomizer requests
    mapping(uint256 randomizerId => RandomizerRequest) pendingRandomizerRequests;
    // random
    uint256 randomValueId;
    mapping(uint256 id => RandomValue) randomValues;
}

struct GameConfig {
    uint8 maxJokers;
    uint8 minBootyPercentage;
    uint8 maxBootyPercentage;
    uint8 minDurability;
    uint8 maxDurability;
    uint32 minPower;
    uint32 maxPower;
    uint8 minPowerUpPercentage;
    uint8 maxPowerUpPercentage;
    uint8 maxPlayerLevel;
    uint8 maxCardLevel;
    uint8 bogoPercentage;
    uint32 minDuration;
    uint32 attackPeriod;
    uint32 defensePeriod;
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
    uint8 level;
    uint32 xp;
    uint64 lastDefendedAt;
    bytes32 username;
    uint256 maxCards;
    uint256 cards;
    uint256 points;
}

struct Card {
    uint256 tokenId;
    address owner;
    uint8 durability;
    uint32 power;
    uint8 rank;
    uint8 suit;
    uint8 level;
    uint32 xp;
    bool underuse;
    uint64 lastAddedAt;
}

struct Attack_ {
    uint256 id;
    AttackStatus status;
    AttackResult result;
    address attacker;
    address defender;
    uint64 startedAt;
}

enum AttackStatus {
    Invalid,
    Flopping,
    WaitingForAttack,
    WaitingForDefense,
    ShowingDown,
    Finalized
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
    Flop,
    ShowDown
}

struct RandomValue {
    bytes32 seed;
    uint256 offset;
}
