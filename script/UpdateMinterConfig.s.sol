// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, Vm, VmLib } from "./BaseScript.s.sol";

struct MinterConfig {
    uint256 price;
    uint256 initialDiscountUntil;
    uint8[2] shares;
    uint8[] winnerRatios;
}

interface IMinterConfigsFacet_ {
    function updateConfig(MinterConfig memory c) external;
}

contract UpdateMinterConfigScript is BaseScript {
    using VmLib for Vm;

    uint256 private constant PRICE = 0.01e18;
    uint256 private constant INITIAL_DISCOUNT_UNTIL = 0;
    uint8 private constant SHARES_TREASURY = 30;
    uint8 private constant SHARES_GAME = 50;

    function _run(uint256, address) internal override {
        address minter = vm.loadDeployment("NFTMinter");

        uint8[] memory winnerRatios = new uint8[](3);
        winnerRatios[0] = 50;
        winnerRatios[1] = 30;
        winnerRatios[2] = 20;
        IMinterConfigsFacet_(minter).updateConfig(
            MinterConfig({
                price: PRICE,
                initialDiscountUntil: INITIAL_DISCOUNT_UNTIL,
                shares: [SHARES_TREASURY, SHARES_GAME],
                winnerRatios: winnerRatios
            })
        );
    }
}
