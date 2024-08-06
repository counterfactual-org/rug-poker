// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";

import { SvgRendererV1 } from "src/SvgRendererV1.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";

contract SaveSvgScript is Script {
    function run() external {
        address game = address(0); // TODO
        address owner = address(0); // TODO
        ISvgRenderer svgRenderer = ISvgRenderer(new SvgRendererV1(game, owner));

        bytes memory svgImage = svgRenderer.render(0);

        saveToFile(svgImage, "data/svg.svg");
    }

    function saveToFile(bytes memory data, string memory fileName) internal {
        vm.writeFile(fileName, string(data));
    }
}
