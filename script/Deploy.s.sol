// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript } from "./BaseScript.s.sol";
import { DiamondDeployer } from "./libraries/DiamondDeployer.sol";

import { AuctionHouse } from "src/AuctionHouse.sol";
import { NFT } from "src/NFT.sol";
import { SvgRendererV1 } from "src/SvgRendererV1.sol";
import { TokenURIRendererV1 } from "src/TokenURIRendererV1.sol";

contract DeployScript is BaseScript {
    uint256 private constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;

    function _run(uint256, address owner) internal override {
        bool staging = _isStaging();
        address randomizer = vm.envAddress("RANDOMIZER");
        address evaluator5 = vm.envAddress("EVALUATOR5");
        address evaluator7 = vm.envAddress("EVALUATOR7");
        address treasury = vm.envAddress("TREASURY");

        address nft = _loadDeployment("NFT");
        if (nft == address(0)) {
            nft = address(
                new NFT{ salt: 0 }(staging, randomizer, MIN_RANDOMIZER_GAS_LIMIT, address(0), "Rug.Poker", "RUG", owner)
            );
            _saveDeployment("NFT", address(nft));
        }

        address game = _loadDeployment("Game");
        if (game == address(0)) {
            game = DiamondDeployer.deployGame(
                staging, nft, randomizer, evaluator5, evaluator7, treasury, MIN_RANDOMIZER_GAS_LIMIT, owner
            );
            _saveDeployment("Game", address(game));
        }

        address nftMinter = _loadDeployment("NFTMinter");
        if (nftMinter == address(0)) {
            nftMinter = DiamondDeployer.deployNFTMinter(nft, treasury, game, owner);
            _saveDeployment("NFTMinter", address(nftMinter));
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
        }
    }
}
