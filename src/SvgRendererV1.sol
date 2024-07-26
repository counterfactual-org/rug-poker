// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";
import { Base64 } from "src/libraries/Base64.sol";

contract SvgRendererV1 is ISvgRenderer {
    function render(uint256 tokenId) external view override returns (bytes memory svg) {
        string memory svgData = string(abi.encodePacked("<svg>", "</svg>"));

        return bytes(svgData);
    }
}
