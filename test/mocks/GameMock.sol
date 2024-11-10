// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IGame } from "src/interfaces/IGame.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";

contract GameMock is IGame {
    receive() external payable { }

    function cardSuit(uint256) external pure returns (uint8) {
        return 0;
    }

    function cardRank(uint256) external pure returns (uint8) {
        return 0;
    }

    function cardDurability(uint256) external pure returns (uint8) {
        return 0;
    }

    function cardPower(uint256) external pure returns (uint32) {
        return 0;
    }

    function cardLevel(uint256) external pure returns (uint8) {
        return 0;
    }

    function checkpoint() external { }

    function increaseBogoOf(address minter, address account) external {
        INFTMinter(minter).increaseBogoOf(account);
    }
}
