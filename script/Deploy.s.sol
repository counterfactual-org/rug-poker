// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript } from "./BaseScript.s.sol";

import { AuctionHouse } from "src/AuctionHouse.sol";
import { Game } from "src/Game.sol";
import { NFT } from "src/NFT.sol";
import { NFTMinter } from "src/NFTMinter.sol";
import { SvgRendererV1 } from "src/SvgRendererV1.sol";
import { TokenURIRendererV1 } from "src/TokenURIRendererV1.sol";

contract DeployScript is BaseScript {
    address private constant RANDOMIZER = address(0x5b8bB80f2d72D0C85caB8fB169e8170A05C94bAF); // TODO
    uint256 private constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;
    address private constant EVALUTOR = address(0); // TODO
    uint256 private constant TOKENS_IN_BATCH = 1000;
    address private constant TREASURY = address(0); // TODO
    uint256 private constant PRICE = 0.009e18;
    uint256 private constant CLAIM_LIMIT = 100;
    Game.Config CONFIG = Game.Config({
        maxCards: 30,
        maxAttacks: 5,
        maxBootyCards: 3,
        minDuration: 1 weeks,
        immunePeriod: 1 hours,
        attackPeriod: 24 hours,
        bootyPercentages: [15, 30, 50],
        attackFees: [uint256(0), 0.003e18, 0.01e18]
    });

    function _run(uint256, address owner) internal override {
        _enforceChain(ARBITRUM);

        address nft = _loadDeployment("NFT");
        if (nft == address(0)) {
            nft = address(
                new NFT{ salt: 0 }("Rug.Poker", "POKER", RANDOMIZER, MIN_RANDOMIZER_GAS_LIMIT, address(0), owner)
            );
            _saveDeployment("NFT", address(nft));
        }

        address game = _loadDeployment("Game");
        if (game == address(0)) {
            game = address(
                new Game{ salt: 0 }(nft, RANDOMIZER, MIN_RANDOMIZER_GAS_LIMIT, EVALUTOR, TREASURY, CONFIG, owner)
            );
            _saveDeployment("Game", address(game));
        }

        address nftMinter = _loadDeployment("NFTMinter");
        if (nftMinter == address(0)) {
            uint8[] memory winnerRatios = new uint8[](3);
            winnerRatios[0] = 50;
            winnerRatios[1] = 30;
            winnerRatios[2] = 20;
            uint256 initialDiscountUntil = (block.timestamp + 2 weeks) * 1 days / 1 days;
            nftMinter = address(
                new NFTMinter{ salt: 0 }(
                    nft,
                    TOKENS_IN_BATCH,
                    TREASURY,
                    game,
                    PRICE,
                    [30, 50],
                    winnerRatios,
                    initialDiscountUntil,
                    CLAIM_LIMIT,
                    owner
                )
            );
            _saveDeployment("NFTMinter", address(nftMinter));
        }

        address svgRenderer = _loadDeployment("SvgRendererV1");
        if (svgRenderer == address(0)) {
            svgRenderer = address(new SvgRendererV1{ salt: 0 }());
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
            auctionHouse = address(new AuctionHouse{ salt: 0 }(nft, TREASURY, owner));
            _saveDeployment("AuctionHouse", address(auctionHouse));
        }
    }
}
