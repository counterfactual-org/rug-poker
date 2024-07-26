// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGame {
    function cardSuit(uint256 tokenId) external view returns (uint8);

    function cardRank(uint256 tokenId) external view returns (uint8);

    function cardDurability(uint256 tokenId) external view returns (uint8);

    function checkpoint() external;
}
