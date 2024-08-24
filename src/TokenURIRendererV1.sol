// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { LibString } from "solmate/utils/LibString.sol";

import {
    RANK_ACE,
    RANK_EIGHT,
    RANK_FIVE,
    RANK_FOUR,
    RANK_JACK,
    RANK_JOKER,
    RANK_KING,
    RANK_NINE,
    RANK_QUEEN,
    RANK_SEVEN,
    RANK_SIX,
    RANK_TEN,
    RANK_THREE,
    RANK_TWO,
    SUIT_CLUB,
    SUIT_DIAMOND,
    SUIT_DIAMOND,
    SUIT_HEART
} from "src/Constants.sol";
import { IGame } from "src/interfaces/IGame.sol";
import { ISvgRenderer } from "src/interfaces/ISvgRenderer.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";
import { Base64 } from "src/libraries/Base64.sol";
import { TokenAttr, TokenAttrType, TokenURILib } from "src/libraries/TokenURILib.sol";

contract TokenURIRendererV1 is ITokenURIRenderer {
    using LibString for uint256;

    address public immutable game;
    address public immutable svgRenderer;

    constructor(address _game, address _svgRenderer) {
        game = _game;
        svgRenderer = _svgRenderer;
    }

    function render(uint256 tokenId) external view returns (bytes memory) {
        TokenAttr[] memory attrs = new TokenAttr[](3);
        attrs[0] = TokenAttr(TokenAttrType.String, "suit", _suit(IGame(game).cardSuit(tokenId)));
        attrs[1] = TokenAttr(TokenAttrType.String, "rank", _rank(IGame(game).cardRank(tokenId)));
        attrs[2] = TokenAttr(TokenAttrType.String, "level", uint256(IGame(game).cardLevel(tokenId)).toString());
        attrs[3] = TokenAttr(TokenAttrType.String, "power", uint256(IGame(game).cardPower(tokenId)).toString());
        attrs[4] =
            TokenAttr(TokenAttrType.String, "durability", uint256(IGame(game).cardDurability(tokenId)).toString());
        string memory name = string.concat("Poker Card #", tokenId.toString());
        string memory description = string.concat("Rug.poker: Mint, Rug and Win!");
        bytes memory svg = ISvgRenderer(svgRenderer).render(tokenId);
        string memory image = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg)));
        return TokenURILib.uri(name, description, image, attrs);
    }

    function _suit(uint8 value) internal pure returns (string memory) {
        if (value == SUIT_CLUB) return "Club";
        if (value == SUIT_DIAMOND) return "Diamond";
        if (value == SUIT_HEART) return "Heart";
        return "Spade";
    }

    function _rank(uint8 value) internal pure returns (string memory) {
        if (value == RANK_JOKER) return "Joker";
        if (value == RANK_ACE) return "Ace";
        if (value == RANK_KING) return "King";
        if (value == RANK_QUEEN) return "Queen";
        if (value == RANK_JACK) return "Jack";
        if (value == RANK_TEN) return "10";
        if (value == RANK_NINE) return "9";
        if (value == RANK_EIGHT) return "8";
        if (value == RANK_SEVEN) return "7";
        if (value == RANK_SIX) return "6";
        if (value == RANK_FIVE) return "5";
        if (value == RANK_FOUR) return "4";
        if (value == RANK_THREE) return "3";
        return "2";
    }
}
