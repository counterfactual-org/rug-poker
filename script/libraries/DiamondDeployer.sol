// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Diamond, DiamondArgs } from "diamond/Diamond.sol";
import { IDiamond } from "diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "diamond/interfaces/IDiamondLoupe.sol";
import { GameConfig, GameInit } from "src/game/GameInit.sol";
import { AttacksFacet } from "src/game/facets/AttacksFacet.sol";
import { CardsFacet } from "src/game/facets/CardsFacet.sol";
import { GameConfigsFacet } from "src/game/facets/GameConfigsFacet.sol";
import { ItemsFacet } from "src/game/facets/ItemsFacet.sol";
import { PlayersFacet } from "src/game/facets/PlayersFacet.sol";
import { IFacet } from "src/interfaces/IFacet.sol";
import { MinterConfig, MinterInit } from "src/minter/MinterInit.sol";
import { JackpotFacet } from "src/minter/facets/JackpotFacet.sol";
import { MintFacet } from "src/minter/facets/MintFacet.sol";
import { MinterConfigsFacet } from "src/minter/facets/MinterConfigsFacet.sol";

library DiamondDeployer {
    uint256 private constant TOKENS_IN_BATCH = 1000;
    uint256 private constant PRICE = 0.01e18;
    uint256 private constant INITIAL_DISCOUNT_UNTIL = 1_733_011_200; // Sun Dec 01 2024 00:00:00 GMT+0000
    uint8 private constant SHARES_TREASURY = 30;
    uint8 private constant SHARES_GAME = 50;
    uint8 private constant WINNER_RATIO_GOLD = 50;
    uint8 private constant WINNER_RATIO_SILVER = 30;
    uint8 private constant WINNER_RATIO_BRONZE = 20;
    address private constant DIAMOND_CUT_FACET = address(0);

    function newGameFacet(uint256 index) internal returns (address) {
        if (index == 0) return address(new AttacksFacet{ salt: 0 }());
        if (index == 1) return address(new CardsFacet{ salt: 0 }());
        if (index == 2) return address(new GameConfigsFacet{ salt: 0 }());
        if (index == 3) return address(new ItemsFacet{ salt: 0 }());
        if (index == 4) return address(new PlayersFacet{ salt: 0 }());
        return address(0);
    }

    function deployGame(
        address diamondCutFacet,
        address diamondLoupeFacet,
        address nft,
        address evaluator9,
        address treasury,
        address owner
    ) internal returns (address[] memory facets, address game) {
        GameInit init = new GameInit{ salt: 0 }();
        facets = new address[](5);
        for (uint256 i; i < 5; ++i) {
            facets[i] = newGameFacet(i);
        }
        game = deployDiamond(
            "Game",
            diamondCutFacet,
            diamondLoupeFacet,
            facets,
            address(init),
            abi.encodeCall(GameInit.init, (nft, evaluator9, treasury, _gameConfig())),
            owner
        );
    }

    function _gameConfig() private pure returns (GameConfig memory) {
        return GameConfig({
            maxJokers: 1,
            minBootyPercentage: 10,
            maxBootyPercentage: 30,
            minDurability: 3,
            maxDurability: 8,
            minDuration: 1 weeks,
            minPower: 10_000,
            maxPower: 30_000,
            minPowerUpPercentage: 30,
            maxPowerUpPercentage: 100,
            maxPlayerLevel: 50,
            maxCardLevel: 10,
            bogoPercentage: 30,
            attackPeriod: 1 hours,
            defensePeriod: 24 hours,
            doubleXPUntil: 0
        });
    }

    function newNFTMinterFacet(uint256 index) internal returns (address) {
        if (index == 0) return address(new JackpotFacet{ salt: 0 }());
        if (index == 1) return address(new MinterConfigsFacet{ salt: 0 }());
        if (index == 2) return address(new MintFacet{ salt: 0 }());
        return address(0);
    }

    function deployNFTMinter(
        address diamondCutFacet,
        address diamondLoupeFacet,
        address nft,
        address treasury,
        address game,
        address owner
    ) internal returns (address[] memory facets, address nftMinter) {
        MinterInit init = new MinterInit{ salt: 0 }();
        facets = new address[](3);
        for (uint256 i; i < 3; ++i) {
            facets[i] = newNFTMinterFacet(i);
        }
        nftMinter = deployDiamond(
            "NFTMinter",
            diamondCutFacet,
            diamondLoupeFacet,
            facets,
            address(init),
            abi.encodeCall(MinterInit.init, (nft, TOKENS_IN_BATCH, treasury, game, _minterConfig())),
            owner
        );
    }

    function _minterConfig() private pure returns (MinterConfig memory) {
        uint8[] memory winnerRatios = new uint8[](3);
        winnerRatios[0] = WINNER_RATIO_GOLD;
        winnerRatios[1] = WINNER_RATIO_SILVER;
        winnerRatios[2] = WINNER_RATIO_BRONZE;
        return MinterConfig({
            price: PRICE,
            initialDiscountUntil: INITIAL_DISCOUNT_UNTIL,
            shares: [SHARES_TREASURY, SHARES_GAME],
            winnerRatios: winnerRatios
        });
    }

    function deployDiamond(
        string memory name,
        address cutFacet,
        address loupeFacet,
        address[] memory facets,
        address init,
        bytes memory initCallData,
        address owner
    ) internal returns (address) {
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](facets.length + 2);
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        cuts[0] = IDiamond.FacetCut(cutFacet, IDiamond.FacetCutAction.Add, cutSelectors);
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        cuts[1] = IDiamond.FacetCut(loupeFacet, IDiamond.FacetCutAction.Add, loupeSelectors);
        for (uint256 i; i < facets.length; ++i) {
            cuts[i + 2] = IDiamond.FacetCut(facets[i], IDiamond.FacetCutAction.Add, IFacet(facets[i]).selectors());
        }
        Diamond diamond = new Diamond{ salt: keccak256(bytes(name)) }(cuts, DiamondArgs(owner, init, initCallData));
        return address(diamond);
    }
}
