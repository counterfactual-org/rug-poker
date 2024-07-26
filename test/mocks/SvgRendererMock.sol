// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibString } from "solmate/utils/LibString.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";

contract SvgRendererMock is ISvgRenderer {
    using LibString for uint256;

    function render(uint256) external pure returns (bytes memory) {
        return bytes(string.concat("<svg></svg>"));
    }
}
