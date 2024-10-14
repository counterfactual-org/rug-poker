// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript } from "./BaseScript.s.sol";
import { DiamondDeployer } from "./libraries/DiamondDeployer.sol";
import { IDiamond } from "diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { AttacksFacet } from "src/game/facets/AttacksFacet.sol";
import { CardsFacet } from "src/game/facets/CardsFacet.sol";
import { GameConfigsFacet } from "src/game/facets/GameConfigsFacet.sol";
import { ItemsFacet } from "src/game/facets/ItemsFacet.sol";
import { PlayersFacet } from "src/game/facets/PlayersFacet.sol";
import { RandomizerFacet } from "src/game/facets/RandomizerFacet.sol";
import { IFacet } from "src/interfaces/IFacet.sol";

contract UpgradeScript is BaseScript {
    bytes4[] private add;
    bytes4[] private replace;
    bytes4[] private remove;
    IDiamondCut.FacetCut[] private cuts;

    function _run(uint256, address) internal override {
        string memory name = vm.envString("DIAMOND_NAME");
        if (bytes(name).length == 0) revert("Diamond name not specified");

        address diamond = _loadDeployment(name);
        if (diamond == address(0)) revert("Diamond not deployed");

        uint256 index = vm.envOr("FACET_INDEX", type(uint256).max);
        address[] memory facets = _loadFacets(name);
        bytes4[] memory oldSelectors = IFacet(facets[index]).selectors();

        address facet;
        if (keccak256(bytes(name)) == keccak256("Game")) {
            facet = DiamondDeployer.newGameFacet(index);
            if (facet == address(0)) revert("Invalid facet index");
        } else if (keccak256(bytes(name)) == keccak256("NFTMinter")) {
            facet = DiamondDeployer.newNFTMinterFacet(index);
            if (facet == address(0)) revert("Invalid facet index");
        } else {
            revert("Invalid diamond name");
        }

        bytes4[] memory newSelectors = IFacet(facet).selectors();

        for (uint256 i; i < newSelectors.length; ++i) {
            if (_contains(oldSelectors, newSelectors[i])) {
                replace.push(newSelectors[i]);
            } else {
                add.push(newSelectors[i]);
            }
        }
        for (uint256 i; i < oldSelectors.length; ++i) {
            if (!_contains(newSelectors, oldSelectors[i])) {
                remove.push(oldSelectors[i]);
            }
        }

        if (add.length > 0) {
            cuts.push(IDiamond.FacetCut(facet, IDiamond.FacetCutAction.Add, add));
        }
        if (replace.length > 0) {
            cuts.push(IDiamond.FacetCut(facet, IDiamond.FacetCutAction.Replace, replace));
        }
        if (remove.length > 0) {
            cuts.push(IDiamond.FacetCut(facet, IDiamond.FacetCutAction.Remove, remove));
        }
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        facets[index] = facet;
        _saveFacets(name, facets);
    }

    function _contains(bytes4[] memory selectors, bytes4 target) private pure returns (bool) {
        for (uint256 i; i < selectors.length; ++i) {
            if (selectors[i] == target) {
                return true;
            }
        }
        return false;
    }
}
