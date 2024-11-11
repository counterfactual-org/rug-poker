// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Owned } from "solmate/auth/Owned.sol";

import { IGame } from "src/interfaces/IGame.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";

contract SvgRendererV1 is Owned, ISvgRenderer {
    address public immutable game;

    mapping(uint8 suit => mapping(uint8 rank => bytes)) public images;

    event UpdateImage(uint8 indexed suit, uint8 indexed rank, bytes indexed image);

    constructor(address _game, address _owner) Owned(_owner) {
        game = _game;
    }

    function updateImages(bytes[56] memory _images) external onlyOwner {
        for (uint8 suit; suit < 4; ++suit) {
            for (uint8 rank; rank < 14; ++rank) {
                bytes memory image = _images[rank * 4 + suit];
                images[suit][rank] = image;

                emit UpdateImage(suit, rank, image);
            }
        }
    }

    function updateImage(uint8 suit, uint8 rank, bytes memory image) external onlyOwner {
        images[suit][rank] = image;

        emit UpdateImage(suit, rank, image);
    }

    function render(uint256 tokenId) external view override returns (string memory svg) {
        uint8 suit = IGame(game).cardSuit(tokenId);
        uint8 rank = IGame(game).cardRank(tokenId);
        return string(images[suit][rank]);
    }
}
