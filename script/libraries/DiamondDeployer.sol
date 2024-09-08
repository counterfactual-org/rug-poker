// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Diamond } from "diamond/Diamond.sol";
import { DiamondCutFacet } from "diamond/facets/DiamondCutFacet.sol";
import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { GameConfig, GameInit } from "src/game/GameInit.sol";
import { AttacksFacet } from "src/game/facets/AttacksFacet.sol";
import { CardsFacet } from "src/game/facets/CardsFacet.sol";
import { GameConfigsFacet } from "src/game/facets/GameConfigsFacet.sol";
import { ItemsFacet } from "src/game/facets/ItemsFacet.sol";
import { PlayersFacet } from "src/game/facets/PlayersFacet.sol";
import { RandomizerFacet } from "src/game/facets/RandomizerFacet.sol";
import { IFacet } from "src/interfaces/IFacet.sol";
import { MinterConfig, MinterInit } from "src/minter/MinterInit.sol";
import { ClaimsFacet } from "src/minter/facets/ClaimsFacet.sol";
import { JackpotFacet } from "src/minter/facets/JackpotFacet.sol";
import { MintFacet } from "src/minter/facets/MintFacet.sol";
import { MinterConfigsFacet } from "src/minter/facets/MinterConfigsFacet.sol";

library DiamondDeployer {
    uint256 private constant TOKENS_IN_BATCH = 1000;
    uint256 private constant PRICE = 0.009e18;
    uint256 private constant CLAIM_LIMIT = 100;
    uint8 private constant SHARES_TREASURY = 30;
    uint8 private constant SHARES_GAME = 50;
    uint8 private constant WINNER_RATIO_GOLD = 50;
    uint8 private constant WINNER_RATIO_SILVER = 30;
    uint8 private constant WINNER_RATIO_BRONZE = 20;

    function deployGame(
        bool staging,
        address nft,
        address randomizer,
        address evaluator9,
        address treasury,
        uint256 randomizerGasLimit,
        address owner
    ) internal returns (address game) {
        GameInit init = new GameInit();
        IFacet[] memory facets = new IFacet[](6);
        facets[0] = new AttacksFacet();
        facets[1] = new CardsFacet();
        facets[2] = new GameConfigsFacet();
        facets[3] = new ItemsFacet();
        facets[4] = new PlayersFacet();
        facets[5] = new RandomizerFacet();
        return deployDiamond(
            facets,
            address(init),
            abi.encodeCall(
                GameInit.init, (staging, nft, randomizer, evaluator9, treasury, randomizerGasLimit, _gameConfig())
            ),
            owner
        );
    }

    function _gameConfig() private pure returns (GameConfig memory) {
        return GameConfig({
            maxJokers: 1,
            minBootyPercentage: 10,
            maxBootyPercentage: 90,
            minDurability: 3,
            maxDurability: 8,
            minDuration: 1 weeks,
            minPower: 10_000,
            maxPower: 100_000,
            minPowerUpPercentage: 3,
            maxPowerUpPercentage: 33,
            maxPlayerLevel: 50,
            maxCardLevel: 10,
            bogoPercentage: 10,
            attackPeriod: 1 hours,
            defensePeriod: 24 hours
        });
    }

    function deployNFTMinter(address nft, address treasury, address game, address owner)
        internal
        returns (address nftMinter)
    {
        MinterInit init = new MinterInit();
        IFacet[] memory facets = new IFacet[](4);
        facets[0] = new ClaimsFacet();
        facets[1] = new JackpotFacet();
        facets[2] = new MinterConfigsFacet();
        facets[3] = new MintFacet();
        return deployDiamond(
            facets,
            address(init),
            abi.encodeCall(MinterInit.init, (nft, TOKENS_IN_BATCH, treasury, game, _minterConfig())),
            owner
        );
    }

    function _minterConfig() private view returns (MinterConfig memory) {
        uint256 initialBonusUntil = (block.timestamp + 2 weeks) * 1 days / 1 days;
        uint8[] memory winnerRatios = new uint8[](3);
        winnerRatios[0] = WINNER_RATIO_GOLD;
        winnerRatios[1] = WINNER_RATIO_SILVER;
        winnerRatios[2] = WINNER_RATIO_BRONZE;
        return MinterConfig({
            price: PRICE,
            initialBonusUntil: initialBonusUntil,
            claimLimit: CLAIM_LIMIT,
            shares: [SHARES_TREASURY, SHARES_GAME],
            winnerRatios: winnerRatios
        });
    }

    function deployDiamond(IFacet[] memory facets, address init, bytes memory initCallData, address owner)
        internal
        returns (address)
    {
        DiamondCutFacet cut = new DiamondCutFacet();
        Diamond diamond = new Diamond(owner, address(cut));
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](facets.length);
        for (uint256 i; i < facets.length; ++i) {
            cuts[i] = IDiamondCut.FacetCut(address(facets[i]), IDiamondCut.FacetCutAction.Add, facets[i].selectors());
        }
        IDiamondCut(address(diamond)).diamondCut(cuts, init, initCallData);
        return address(diamond);
    }
}
