// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEvaluator {
    enum HandRank {
        HighCard,
        OnePair,
        TwoPair,
        ThreeOfAKind,
        Straight,
        Flush,
        FullHouse,
        FourOfAKind,
        StraightFlush
    }

    function handRank(uint256[] memory cards) external view returns (HandRank rank, uint256 val);

    function evaluate(uint256[] memory cards) external view returns (uint256);

    error InvalidNumberOfCards();
}
