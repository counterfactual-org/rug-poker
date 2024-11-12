// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, console } from "./BaseScript.s.sol";

interface IDiamondLoupeFacet_ {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    function facets() external view returns (Facet[] memory facets_);
}

contract InspectDiamondScript is BaseScript {
    function _run(uint256, address) internal override {
        string memory name = vm.envString("DIAMOND_NAME");
        if (bytes(name).length == 0) revert("Diamond name not specified");

        address diamond = _loadDeployment(name);
        if (diamond == address(0)) revert("Diamond not deployed");

        IDiamondLoupeFacet_.Facet[] memory facets = IDiamondLoupeFacet_(diamond).facets();
        for (uint256 i; i < facets.length; ++i) {
            console.log("Facet", facets[i].facetAddress);
            for (uint256 j; j < facets[i].functionSelectors.length; ++j) {
                console.logBytes4(facets[i].functionSelectors[j]);
            }
        }
    }
}
