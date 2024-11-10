// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SvgRendererMock } from "../mocks/SvgRendererMock.sol";

import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";
import { Base64 } from "src/libraries/Base64.sol";

contract TokenURIRendererMock is ITokenURIRenderer {
    SvgRendererMock svgRenderer = new SvgRendererMock();

    function render(uint256 tokenId) external view returns (string memory) {
        string memory svg = ISvgRenderer(svgRenderer).render(tokenId);
        string memory dataURI = string.concat(
            '{"name":"Poker NFT","description":"","image":"',
            string(abi.encodePacked("data:image/svg+xml;base64,", svg)),
            '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(dataURI)));
    }
}
