// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

struct MinterStorage {
    // configs
    address nft;
    uint256 tokensInBatch;
    address treasury;
    address game;
    uint256 configVersion;
    mapping(uint256 => MinterConfig) configs;
    // claims
    mapping(bytes32 merkleRoot => bool) isMerkleRoot;
    mapping(bytes32 merkleRoot => mapping(address account => bool)) hasClaimed;
    mapping(bytes32 merkleRoot => uint256) totalClaimed;
    mapping(uint256 id => bool) isAirdrop;
    // freeMintings
    mapping(address account => uint256) bogo;
    // jackpot
    address[] entrants;
    uint256 entrantsOffset;
    uint256 batchId;
}

struct MinterConfig {
    uint256 price;
    uint256 initialBonusUntil;
    uint256 claimLimit;
    uint8[2] shares;
    uint8[] winnerRatios;
}
