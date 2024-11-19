// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { DiamondCutFacet } from "diamond/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "diamond/facets/DiamondLoupeFacet.sol";
import { Script, console } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";
import { LibString } from "solmate/utils/LibString.sol";

library VmLib {
    using LibString for uint256;

    function isStaging(Vm vm) internal view returns (bool) {
        return vm.envOr("STAGING", false);
    }

    function privateKey(Vm vm) internal view returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    function caller(Vm vm) internal returns (address _caller) {
        (, _caller,) = vm.readCallers();
    }

    function computeCreate2Address(Vm vm, string memory name) internal view returns (address) {
        return vm.computeCreate2Address(0, keccak256(vm.getCode(name)));
    }

    function saveDeployment(Vm vm, string memory name, address addr) internal {
        if (!vm.exists("./deployments/")) {
            vm.createDir("./deployments/", false);
        }
        string memory chainId = block.chainid.toString();
        string memory path = string.concat("./deployments/", chainId, ".json");
        string memory key = string.concat("deployment:", chainId);
        if (vm.exists(path)) {
            vm.serializeJson(key, vm.readFile(path));
        }
        vm.writeJson(vm.serializeAddress(key, name, address(addr)), path);
    }

    function saveFacets(Vm vm, string memory name, address[] memory facets) internal {
        if (!vm.exists("./facets/")) {
            vm.createDir("./facets/", false);
        }
        string memory chainId = block.chainid.toString();
        string memory path = string.concat("./facets/", chainId, ".json");
        string memory key = string.concat("facets:", chainId);
        if (vm.exists(path)) {
            vm.serializeJson(key, vm.readFile(path));
        }
        vm.writeJson(vm.serializeAddress(key, name, facets), path);
    }

    function loadDeployment(Vm vm, string memory name) internal returns (address) {
        return loadDeployment(vm, block.chainid, name);
    }

    function loadDeployment(Vm vm, uint256 chainId, string memory name) internal returns (address) {
        string memory _chainId = chainId.toString();
        string memory path = string.concat("./deployments/", _chainId, ".json");
        if (!vm.exists(path)) return address(0);
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", name);
        if (!vm.keyExists(json, key)) return address(0);
        return vm.parseJsonAddress(json, key);
    }

    function loadFacets(Vm vm, string memory name) internal returns (address[] memory) {
        return loadFacets(vm, block.chainid, name);
    }

    function loadFacets(Vm vm, uint256 chainId, string memory name) internal returns (address[] memory) {
        string memory _chainId = chainId.toString();
        string memory path = string.concat("./facets/", _chainId, ".json");
        if (!vm.exists(path)) revert(string.concat(path, " does not exist"));
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", name);
        if (!vm.exists(path)) revert(string.concat(name, " does not exist"));
        if (!vm.keyExists(json, key)) return new address[](0);
        return vm.parseJsonAddressArray(json, key);
    }

    function loadConstantUint(Vm vm, string memory name) internal view returns (uint256) {
        return loadConstantUint(vm, block.chainid, name);
    }

    function loadConstantAddress(Vm vm, string memory name) internal view returns (address) {
        return loadConstantAddress(vm, block.chainid, name);
    }

    function loadConstant(Vm vm) internal view returns (string memory json) {
        return loadConstants(vm, block.chainid);
    }

    function loadConstantUint(Vm vm, uint256 chainId, string memory name) internal view returns (uint256) {
        string memory json = loadConstants(vm, chainId);
        return vm.parseJsonUint(json, jsonKey(vm, json, name));
    }

    function loadConstantAddress(Vm vm, uint256 chainId, string memory name) internal view returns (address) {
        string memory json = loadConstants(vm, chainId);
        return vm.parseJsonAddress(json, jsonKey(vm, json, name));
    }

    function loadConstants(Vm vm, uint256 chainId) internal view returns (string memory json) {
        string memory _chainId = chainId.toString();
        json = vm.readFile(string.concat("./constants/", _chainId, ".json"));
    }

    function jsonKey(Vm vm, string memory json, string memory name) internal view returns (string memory key) {
        key = string.concat(".", name);
        if (!vm.keyExists(json, key)) revert(string.concat("constant ", name, " doesn't exist"));
    }
}
