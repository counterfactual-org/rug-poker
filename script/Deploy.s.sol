// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, console } from "./BaseScript.s.sol";
import { DiamondDeployer } from "./libraries/DiamondDeployer.sol";
import { DiamondCutFacet } from "diamond/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "diamond/facets/DiamondLoupeFacet.sol";

import { LibString } from "solmate/utils/LibString.sol";
import { AuctionHouse } from "src/AuctionHouse.sol";
import { NFT } from "src/NFT.sol";
import { SvgRendererV1 } from "src/SvgRendererV1.sol";
import { TokenURIRendererV1 } from "src/TokenURIRendererV1.sol";
import { IFacet } from "src/interfaces/IFacet.sol";

contract DeployScript is BaseScript {
    using LibString for uint256;

    uint256 private constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;

    function _run(uint256, address owner) internal override {
        bool staging = _isStaging();
        address randomizer = vm.envAddress("RANDOMIZER");
        address evaluator9 = vm.envAddress("EVALUATOR9");
        address treasury = vm.envAddress("TREASURY");

        address cut = vm.computeCreate2Address(0, keccak256(vm.getCode("DiamondCutFacet")));
        if (cut.code.length == 0) {
            cut = address(new DiamondCutFacet{ salt: 0 }());
        }
        address loupe = vm.computeCreate2Address(0, keccak256(vm.getCode("DiamondLoupeFacet")));
        if (loupe.code.length == 0) {
            loupe = address(new DiamondLoupeFacet{ salt: 0 }());
        }

        address nft = _loadDeployment("NFT");
        if (nft == address(0)) {
            nft = address(
                new NFT{ salt: 0 }(staging, randomizer, MIN_RANDOMIZER_GAS_LIMIT, address(0), "Rug.Poker", "RUG", owner)
            );
            _saveDeployment("NFT", address(nft));
        }

        address[] memory facets;
        address game = _loadDeployment("Game");
        if (game == address(0)) {
            (facets, game) = DiamondDeployer.deployGame(
                staging, cut, loupe, nft, randomizer, evaluator9, treasury, MIN_RANDOMIZER_GAS_LIMIT, owner
            );
            _saveDeployment("Game", address(game));
            _saveFacets("Game", facets);
            NFT(nft).updateApp(game, true);
        }

        address nftMinter = _loadDeployment("NFTMinter");
        if (nftMinter == address(0)) {
            (facets, nftMinter) = DiamondDeployer.deployNFTMinter(cut, loupe, nft, treasury, game, owner);
            _saveDeployment("NFTMinter", address(nftMinter));
            _saveFacets("NFTMinter", facets);
            NFT(nft).updateMinter(nftMinter);
        }

        address svgRenderer = _loadDeployment("SvgRendererV1");
        if (svgRenderer == address(0)) {
            svgRenderer = address(new SvgRendererV1{ salt: 0 }(game, owner));
            _saveDeployment("SvgRendererV1", address(svgRenderer));
        }

        address tokenURIRenderer = _loadDeployment("TokenURIRendererV1");
        if (tokenURIRenderer == address(0)) {
            tokenURIRenderer = address(new TokenURIRendererV1{ salt: 0 }(game, svgRenderer));
            _saveDeployment("TokenURIRendererV1", address(tokenURIRenderer));
            NFT(nft).updateTokenURIRenderer(tokenURIRenderer);
        }

        address auctionHouse = _loadDeployment("AuctionHouse");
        if (auctionHouse == address(0)) {
            auctionHouse = address(new AuctionHouse{ salt: 0 }(nft, treasury, owner));
            _saveDeployment("AuctionHouse", address(auctionHouse));
            NFT(nft).updateApp(auctionHouse, true);
        }
    }
}
