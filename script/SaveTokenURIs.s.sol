// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, Vm, VmLib, console } from "./BaseScript.s.sol";
import { LibString } from "solmate/utils/LibString.sol";
import { IGame } from "src/interfaces/IGame.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";

contract SaveTokenURIsScript is BaseScript {
    using VmLib for Vm;
    using LibString for uint256;

    mapping(uint8 suit => mapping(uint8 rank => bool)) private _rendered;
    mapping(uint8 => string) private suitChars;
    mapping(uint8 => string) private suitCharsJoker;
    mapping(uint8 => string) private rankChars;

    constructor() {
        suitChars[0] = "s";
        suitChars[1] = "h";
        suitChars[2] = "d";
        suitChars[3] = "c";
        suitCharsJoker[0] = "2";
        suitCharsJoker[1] = "1";
        suitCharsJoker[2] = "1";
        suitCharsJoker[3] = "2";

        rankChars[0] = "2";
        rankChars[1] = "3";
        rankChars[2] = "4";
        rankChars[3] = "5";
        rankChars[4] = "6";
        rankChars[5] = "7";
        rankChars[6] = "8";
        rankChars[7] = "9";
        rankChars[8] = "T";
        rankChars[9] = "J";
        rankChars[10] = "Q";
        rankChars[11] = "K";
        rankChars[12] = "A";
        rankChars[13] = "Z";
    }

    function _run(uint256, address) internal override {
        address minter = vm.loadDeployment("NFTMinter");
        address game = vm.loadDeployment("Game");
        address svgRenderer = vm.loadDeployment("SvgRendererV1");
        address tokenURIRenderer = vm.loadDeployment("TokenURIRendererV1");

        for (uint256 i; i < 100; ++i) {
            INFTMinter(minter).mint{ value: 0.07e18 }(10);
        }

        for (uint256 tokenId; tokenId < 1500; ++tokenId) {
            uint8 suit = IGame(game).cardSuit(tokenId);
            uint8 rank = IGame(game).cardRank(tokenId);
            if (_rendered[suit][rank]) continue;

            string memory r = rankChars[rank];
            string memory s = rank == 13 ? suitCharsJoker[suit] : suitChars[suit];

            string memory svg = ISvgRenderer(svgRenderer).render(tokenId);
            saveToFile("data/svgs/", string.concat(r, s, ".svg"), svg);

            string memory tokenURI = ITokenURIRenderer(tokenURIRenderer).render(tokenId);
            saveToFile("data/token-uris/", string.concat(r, s), tokenURI);

            _rendered[suit][rank] = true;
        }
    }

    function saveToFile(string memory dir, string memory fileName, string memory data) internal {
        if (!vm.exists(dir)) {
            vm.createDir(dir, true);
        }
        vm.writeFile(string.concat(dir, fileName), string(data));
    }
}
