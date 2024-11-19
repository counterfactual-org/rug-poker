// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, Vm, VmLib, console } from "./BaseScript.s.sol";
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
    using VmLib for Vm;
    using LibString for uint256;

    function _run(uint256, address owner) internal override {
        address evaluator9 = vm.envAddress("EVALUATOR9");
        address treasury = vm.envAddress("TREASURY");

        address cut = vm.computeCreate2Address("DiamondCutFacet");
        if (cut.code.length == 0) {
            cut = address(new DiamondCutFacet{ salt: 0 }());
        }
        address loupe = vm.computeCreate2Address("DiamondLoupeFacet");
        if (loupe.code.length == 0) {
            loupe = address(new DiamondLoupeFacet{ salt: 0 }());
        }

        address nft = vm.loadDeployment("NFT");
        if (nft == address(0)) {
            nft = address(new NFT{ salt: 0 }(address(0), "Rug.Poker", "RUG", owner));
            vm.saveDeployment("NFT", address(nft));
        }

        address[] memory facets;
        address game = vm.loadDeployment("Game");
        if (game == address(0)) {
            (facets, game) = DiamondDeployer.deployGame(cut, loupe, nft, evaluator9, treasury, owner);
            vm.saveDeployment("Game", address(game));
            vm.saveFacets("Game", facets);
            NFT(nft).updateApp(game, true);
        }

        address nftMinter = vm.loadDeployment("NFTMinter");
        if (nftMinter == address(0)) {
            (facets, nftMinter) = DiamondDeployer.deployNFTMinter(cut, loupe, nft, treasury, game, owner);
            vm.saveDeployment("NFTMinter", address(nftMinter));
            vm.saveFacets("NFTMinter", facets);
            NFT(nft).updateMinter(nftMinter);
        }

        address svgRenderer = vm.loadDeployment("SvgRendererV1");
        if (svgRenderer == address(0)) {
            svgRenderer = address(new SvgRendererV1{ salt: 0 }(game, owner));
            vm.saveDeployment("SvgRendererV1", address(svgRenderer));
        }

        address tokenURIRenderer = vm.loadDeployment("TokenURIRendererV1");
        if (tokenURIRenderer == address(0)) {
            tokenURIRenderer = address(new TokenURIRendererV1{ salt: 0 }(game, svgRenderer));
            vm.saveDeployment("TokenURIRendererV1", address(tokenURIRenderer));
            NFT(nft).updateTokenURIRenderer(tokenURIRenderer);
        }

        // address auctionHouse = vm.loadDeployment("AuctionHouse");
        // if (auctionHouse == address(0)) {
        //     auctionHouse = address(new AuctionHouse{ salt: 0 }(nft, treasury, owner));
        //     vm.saveDeployment("AuctionHouse", address(auctionHouse));
        //     NFT(nft).updateApp(auctionHouse, true);
        // }
    }
}
