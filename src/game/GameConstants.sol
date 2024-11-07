// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "../Constants.sol";

uint256 constant CARDS = 9;
uint256 constant COMMUNITY_CARDS = 7;
uint256 constant FLOPPED_CARDS = 5;
uint256 constant HOLE_CARDS = 2;

uint256 constant ATTACK_ROUNDS = 3;

uint256 constant ITEM_ID_REPAIR = 0;
uint256 constant ITEM_ID_JOKERIZE = 1;
uint256 constant ITEM_ID_CHANGE_RANK = 2;
uint256 constant ITEM_ID_CHANGE_SUIT = 3;
