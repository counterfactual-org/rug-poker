// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";

import { SvgRendererV1 } from "src/SvgRendererV1.sol";
import { TokenURIRendererV1 } from "src/TokenURIRendererV1.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";

contract SaveTokenURIScript is Script {
    function run() external {
        address game = address(0); // TODO
        address owner = address(0); // TODO
        ITokenURIRenderer renderer =
            ITokenURIRenderer(new TokenURIRendererV1(game, address(new SvgRendererV1(game, owner))));

        bytes memory tokenURI = renderer.render(0);

        saveToFile(tokenURI, "data/token-uri.data");
    }

    function saveToFile(bytes memory data, string memory fileName) internal {
        vm.writeFile(fileName, string(data));
    }
}
