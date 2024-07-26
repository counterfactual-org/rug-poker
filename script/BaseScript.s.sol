// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { LibString } from "solmate/utils/LibString.sol";

abstract contract BaseScript is Script {
    using LibString for uint256;

    struct LZChain {
        uint256 chainId;
        string name;
        uint16 lzChainId;
        address lzEndpoint;
    }

    LZChain internal MAINNET =
        LZChain(_isStaging() ? 8001 : 1, "Mainnet", 101, address(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675));
    LZChain internal ARBITRUM =
        LZChain(_isStaging() ? 50_161 : 42_161, "Arbitrum", 110, address(0x3c2269811836af69497E5F486A85D7316753cf62));

    LZChain[] internal _chains;

    constructor() {
        _chains.push(MAINNET);
        _chains.push(ARBITRUM);
    }

    function run() external {
        uint256 privateKey = _privateKey();
        vm.startBroadcast(privateKey);
        _run(privateKey, vm.addr(privateKey));
        vm.stopBroadcast();

        _run();
    }

    function _run(uint256 privateKey, address account) internal virtual { }

    function _run() internal virtual { }

    function _isStaging() internal view virtual returns (bool) {
        return vm.envOr("STAGING", false);
    }

    function _privateKey() internal view virtual returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    function _currentChain() internal view returns (LZChain memory chain) {
        for (uint256 i; i < _chains.length; ++i) {
            if (_chains[i].chainId == block.chainid) return _chains[i];
        }
    }

    function _enforceChain(LZChain memory chain) internal view virtual {
        if (block.chainid != chain.chainId) revert(string.concat("Not ", chain.name));
    }

    function _saveDeployment(string memory name, address addr) internal {
        if (!vm.exists("./deployments/")) {
            vm.createDir("./deployments/", false);
        }
        string memory chainId = block.chainid.toString();
        string memory path = string.concat("./deployments/", chainId, ".json");
        if (vm.exists(path)) {
            vm.serializeJson(chainId, vm.readFile(path));
        }
        vm.writeJson(vm.serializeAddress(chainId, name, address(addr)), path);
    }

    function _loadDeployment(string memory name) internal returns (address) {
        return _loadDeployment(_currentChain().chainId, name);
    }

    function _loadDeployment(uint256 chainId, string memory name) internal returns (address) {
        string memory _chainId = chainId.toString();
        string memory path = string.concat("./deployments/", _chainId, ".json");
        if (!vm.exists(path)) return address(0);
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", name);
        if (!vm.keyExists(json, key)) return address(0);
        return vm.parseJsonAddress(json, key);
    }

    function _loadConstantUint(string memory name) internal view returns (uint256) {
        return _loadConstantUint(_currentChain().chainId, name);
    }

    function _loadConstantAddress(string memory name) internal view returns (address) {
        return _loadConstantAddress(_currentChain().chainId, name);
    }

    function _loadConstant() internal view returns (string memory json) {
        return _loadConstants(_currentChain().chainId);
    }

    function _loadConstantUint(uint256 chainId, string memory name) internal view returns (uint256) {
        string memory json = _loadConstants(chainId);
        return vm.parseJsonUint(json, _jsonKey(json, name));
    }

    function _loadConstantAddress(uint256 chainId, string memory name) internal view returns (address) {
        string memory json = _loadConstants(chainId);
        return vm.parseJsonAddress(json, _jsonKey(json, name));
    }

    function _loadConstants(uint256 chainId) internal view returns (string memory json) {
        string memory _chainId = chainId.toString();
        json = vm.readFile(string.concat("./constants/", _chainId, ".json"));
    }

    function _jsonKey(string memory json, string memory name) internal view returns (string memory key) {
        key = string.concat(".", name);
        if (!vm.keyExists(json, key)) revert(string.concat("constant ", name, " doesn't exist"));
    }
}
