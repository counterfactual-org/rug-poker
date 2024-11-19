// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, Vm, VmLib } from "./BaseScript.s.sol";

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

interface IGameConfigsFacet_ {
    function updateConfig(GameConfig memory c) external;
}

contract UpdateGameConfigScript is BaseScript {
    using VmLib for Vm;

    function _run(uint256, address) internal override {
        address game = vm.loadDeployment("Game");

        IGameConfigsFacet_(game).updateConfig(
            GameConfig({
                maxJokers: 1,
                minBootyPercentage: 10,
                maxBootyPercentage: 30,
                minDurability: 3,
                maxDurability: 8,
                minDuration: 1 weeks,
                minPower: 10_000,
                maxPower: 30_000,
                minPowerUpPercentage: 30,
                maxPowerUpPercentage: 100,
                maxPlayerLevel: 50,
                maxCardLevel: 10,
                bogoPercentage: 30,
                attackPeriod: 1 hours,
                defensePeriod: 24 hours
            })
        );
    }
}
