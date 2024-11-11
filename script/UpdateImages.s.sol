// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseScript, console } from "./BaseScript.s.sol";
import { Base64 } from "src/libraries/Base64.sol";

interface ISvgRenderer_ {
    function updateImages(bytes[56] memory _images) external;

    function updateImage(uint8 suit, uint8 rank, bytes memory image) external;
}

contract UpdateImagesScript is BaseScript {
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
        address renderer = _loadDeployment("SvgRendererV1");

        for (uint8 suit; suit < 4; ++suit) {
            for (uint8 rank; rank < 14; ++rank) {
                string memory r = rankChars[rank];
                string memory s = rank == 13 ? suitCharsJoker[suit] : suitChars[suit];
                string memory path = string.concat("res/svg/", r, s, ".svg");
                bytes memory image = vm.readFileBinary(path);
                ISvgRenderer_(renderer).updateImage(suit, rank, image);
            }
        }
    }
}
