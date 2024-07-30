// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./Constants.sol";

struct AppStorage {
    // configs
    address nft;
    address randomizer;
    address evaluator;
    uint256 randomizerGasLimit;
    address treasury;
    uint256 configVersion;
    mapping(uint256 version => Config) configs;
    // rewards
    uint256 reserve;
    uint256 accRewardPerShare;
    mapping(address account => uint256) claimableRewardOf;
    mapping(address account => uint256) accReward;
    uint256 sharesSum;
    mapping(address account => uint256) sharesOf;
    mapping(address account => uint256) rewardDebt;
    // cards
    mapping(address account => Player) playerOf;
    mapping(uint256 tokenId => Card) cardOf;
    // attacks
    uint256 lastAttackId;
    mapping(uint256 attackId => Attack_) attacks;
    mapping(address attacker => mapping(address defender => bool)) hasAttacked;
    mapping(uint256 attackId => uint256[HOLE_CARDS]) attackingTokenIds;
    mapping(uint256 attackId => uint256[HOLE_CARDS]) defendingTokenIds;
    mapping(address account => uint256) incomingAttackId;
    mapping(address account => uint256[]) outgoingAttackIds;
    // attack resolver
    mapping(uint256 randomizerId => uint256 attackId) pendingRandomizerRequests;
}

struct Config {
    uint8 maxCards;
    uint8 maxAttacks;
    uint8 maxBootyCards;
    uint32 minDuration;
    uint32 immunePeriod;
    uint32 attackPeriod;
    uint8[3] bootyPercentages;
    uint256[3] attackFees;
}

struct Player {
    uint256 cards;
    bool hasPlayed;
    uint64 lastDefendedAt;
}

struct Card {
    uint8 durability;
    bool added;
    bool underuse;
    address owner;
    uint64 lastAddedAt;
}

struct Attack_ {
    bool resolving;
    bool finalized;
    AttackResult result;
    uint8 bootyPercentage;
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
