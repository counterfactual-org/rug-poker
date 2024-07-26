// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { LibString } from "solmate/utils/LibString.sol";

import { IGame } from "src/interfaces/IGame.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";
import { Base64 } from "src/libraries/Base64.sol";

contract TokenURIRendererV1 is ITokenURIRenderer {
    using LibString for uint256;

    address public immutable game;
    address public immutable svgRenderer;

    constructor(address _game, address _svgRenderer) {
        game = _game;
        svgRenderer = _svgRenderer;
    }

    function render(uint256 tokenId) external view returns (bytes memory) {
        bytes memory svg = ISvgRenderer(svgRenderer).render(tokenId);
        bytes memory dataURI = abi.encodePacked(
            '{"name": "Poker #',
            tokenId.toString(),
            '","description": "",',
            '"image": "',
            string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg))),
            '","attributes":[{"trait_type":"suit","value":"',
            uint256(IGame(game).cardSuit(tokenId)).toString(),
            '"},{"trait_type":"rank","value":"',
            uint256(IGame(game).cardSuit(tokenId)).toString(),
            '"},{"trait_type":"durability","value":"',
            uint256(IGame(game).cardDurability(tokenId)).toString(),
            '"}]}'
        );
        return abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI));
    }
}
