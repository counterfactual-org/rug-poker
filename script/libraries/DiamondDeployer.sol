// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Diamond } from "diamond/Diamond.sol";
import { DiamondCutFacet } from "diamond/facets/DiamondCutFacet.sol";
import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
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
        return MinterConfig(PRICE, initialBonusUntil, CLAIM_LIMIT, [SHARES_TREASURY, SHARES_GAME], winnerRatios);
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
