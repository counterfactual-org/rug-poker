// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

uint8 constant RANK_TWO = 0;
uint8 constant RANK_THREE = 1;
uint8 constant RANK_FOUR = 2;
uint8 constant RANK_FIVE = 3;
uint8 constant RANK_SIX = 4;
uint8 constant RANK_SEVEN = 5;
uint8 constant RANK_EIGHT = 6;
uint8 constant RANK_NINE = 7;
uint8 constant RANK_TEN = 8;
uint8 constant RANK_JACK = 9;
uint8 constant RANK_QUEEN = 10;
uint8 constant RANK_KING = 11;
uint8 constant RANK_ACE = 12;
uint8 constant RANK_JOKER = 13;

uint8 constant SUIT_SPADE = 0;
uint8 constant SUIT_HEART = 1;
uint8 constant SUIT_DIAMOND = 2;
uint8 constant SUIT_CLUB = 3;

uint8 constant FIELD_DURABILITY = 0;
uint8 constant FIELD_RANK = 1;
uint8 constant FIELD_SUIT = 2;

uint8 constant MAX_DURABILITY = 8;
uint8 constant MIN_DURABILITY = 3;
uint256 constant HOLE_CARDS = 5;
uint256 constant COMMUNITY_CARDS = 2;
uint256 constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;
