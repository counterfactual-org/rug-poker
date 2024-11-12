// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, console } from "./BaseScript.s.sol";

interface IMintFacet_ {
    function airdrop(bytes calldata accounts, uint8 size) external;
}

contract AirdropScript is BaseScript {
    function _run(uint256, address) internal override {
        address minter = _loadDeployment("NFTMinter");

        address[] memory accounts = vm.envAddress("AIRDROP_ACCOUNTS", ":");
        bytes memory _accounts;
        for (uint256 i; i < accounts.length; ++i) {
            _accounts = abi.encodePacked(_accounts, accounts[i]);
        }
        uint8 size = uint8(vm.envUint("AIRDROP_SIZE"));

        IMintFacet_(minter).airdrop(_accounts, size);
    }
}
