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
    // freeMintings
    mapping(address account => uint256) bogo;
    // jackpot
    address[] entrants;
    uint256 entrantsOffset;
    uint256 batchId;
}

struct MinterConfig {
    uint256 price;
    uint256 initialDiscountUntil;
    uint8[2] shares;
    uint8[] winnerRatios;
}
