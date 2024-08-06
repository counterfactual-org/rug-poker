// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Owned } from "solmate/auth/Owned.sol";

import { IGame } from "src/interfaces/IGame.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";
import { Base64 } from "src/libraries/Base64.sol";

contract SvgRendererV1 is Owned, ISvgRenderer {
    address public immutable game;

    mapping(uint8 suit => mapping(uint8 rank => bytes)) private _images;

    event UpdateImage(uint8 indexed suit, uint8 indexed rank, bytes indexed image);

    constructor(address _game, address _owner) Owned(_owner) {
        game = _game;
    }

    function updateImage(uint8 suit, uint8 rank, bytes memory image) external onlyOwner {
        _images[suit][rank] = image;

        emit UpdateImage(suit, rank, image);
    }

    function render(uint256 tokenId) external view override returns (bytes memory svg) {
        uint8 suit = IGame(game).cardSuit(tokenId);
        uint8 rank = IGame(game).cardRank(tokenId);
        return _images[suit][rank];
    }
}
