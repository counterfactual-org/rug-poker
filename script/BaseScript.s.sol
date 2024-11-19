// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm, VmLib } from "./libraries/VmLib.sol";
import { Script, console } from "forge-std/Script.sol";
import { LibString } from "solmate/utils/LibString.sol";

abstract contract BaseScript is Script {
    using VmLib for Vm;
    using LibString for uint256;

    struct LZChain {
        uint256 chainId;
        string name;
        uint16 lzChainId;
        address lzEndpoint;
    }

    LZChain internal MAINNET = LZChain(1, "Mainnet", 30_101, address(0x1a44076050125825900e736c501f859c50fE728c));
    LZChain internal MAINNET_STAGING =
        LZChain(1, "Mainnet Staging", 30_101, address(0x1a44076050125825900e736c501f859c50fE728c));
    LZChain internal SEPOLIA =
        LZChain(11_155_111, "Sepolia", 40_161, address(0x6EDCE65403992e310A62460808c4b910D972f10f));

    LZChain internal ARBITRUM =
        LZChain(42_161, "Arbitrum Staging", 30_110, address(0x1a44076050125825900e736c501f859c50fE728c));
    LZChain internal ARBITRUM_STAGING =
        LZChain(50_161, "Arbitrum", 30_110, address(0x1a44076050125825900e736c501f859c50fE728c));
    LZChain internal ARBITRUM_SEPOLIA =
        LZChain(421_614, "Arbitrum Sepolia", 40_231, address(0x6EDCE65403992e310A62460808c4b910D972f10f));

    LZChain[] internal _chains;

    constructor() {
        _chains.push(MAINNET);
        _chains.push(ARBITRUM);
    }

    function run() external {
        uint256 privateKey = vm.privateKey();
        vm.startBroadcast(privateKey);
        _run(privateKey, vm.addr(privateKey));
        vm.stopBroadcast();

        _run();
    }

    function _run(uint256 privateKey, address account) internal virtual { }

    function _run() internal virtual { }
}
