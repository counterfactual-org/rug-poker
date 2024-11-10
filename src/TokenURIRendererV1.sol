// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { LibString } from "solmate/utils/LibString.sol";
import { Base64 } from "src/libraries/Base64.sol";

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
import { TokenAttr, TokenAttrType, TokenURILib } from "src/libraries/TokenURILib.sol";

contract TokenURIRendererV1 is ITokenURIRenderer {
    using LibString for uint256;

    address public immutable game;
    address public immutable svgRenderer;

    constructor(address _game, address _svgRenderer) {
        game = _game;
        svgRenderer = _svgRenderer;
    }

    function render(uint256 tokenId) external view returns (string memory) {
        uint8 suit = IGame(game).cardSuit(tokenId);
        uint8 rank = IGame(game).cardRank(tokenId);
        uint8 level = IGame(game).cardLevel(tokenId);
        uint32 power = IGame(game).cardPower(tokenId);
        uint8 durability = IGame(game).cardDurability(tokenId);

        TokenAttr[] memory attrs = new TokenAttr[](5);
        attrs[0] = TokenAttr(TokenAttrType.String, "suit", _suit(suit));
        attrs[1] = TokenAttr(TokenAttrType.String, "rank", _rank(rank));
        attrs[2] = TokenAttr(TokenAttrType.Number, "level", uint256(level).toString());
        attrs[3] = TokenAttr(TokenAttrType.Number, "power", uint256(power).toString());
        attrs[4] = TokenAttr(TokenAttrType.Number, "durability", uint256(durability).toString());

        string memory name = string.concat("#", tokenId.toString(), ": ", _name(suit, rank));
        string memory description = string.concat("Rug.poker: Mint, Rug and Win. Visit https://rug.poker to play!");
        string memory svg = ISvgRenderer(svgRenderer).render(tokenId);
        string memory image = string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(svg)));

        return TokenURILib.uri(name, description, image, attrs);
    }

    function _name(uint8 suit, uint8 rank) internal pure returns (string memory) {
        if (rank == RANK_JOKER) return "Joker";
        return string.concat(_rank(rank), " of ", _suit(suit), "s");
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
        if (value == RANK_TEN) return "Ten";
        if (value == RANK_NINE) return "Nine";
        if (value == RANK_EIGHT) return "Eight";
        if (value == RANK_SEVEN) return "Seven";
        if (value == RANK_SIX) return "Six";
        if (value == RANK_FIVE) return "Five";
        if (value == RANK_FOUR) return "Four";
        if (value == RANK_THREE) return "Three";
        return "Two";
    }
}
