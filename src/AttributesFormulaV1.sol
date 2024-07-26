// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IAttributesFormula } from "src/interfaces/IAttributesFormula.sol";

contract AttributesFormulaV1 is IAttributesFormula {
    uint16 public constant MIN_MULTIPLIER = 10_000;
    uint16 public constant MAX_MULTIPLIER = 20_000;
    uint16 public constant MIN_DURABILITY = 1;
    uint16 public constant MAX_DURABILITY = 8;
    uint64 public constant MIN_DURATION = 1 weeks;
    uint64 public constant MAX_DURATION = 52 weeks;

    function multiplier(uint256 _tokenId, uint16 _x) external pure returns (uint16 _y) {
        uint256 c = _rarityCoefficient(_tokenId);
        return uint16(_min(uint256(MIN_MULTIPLIER) + c * uint256(_calculate(_x)), uint256(MAX_MULTIPLIER)));
    }

    function durability(uint256, uint16 _x) external pure returns (uint16 _y) {
        return uint16(_min(uint256(MIN_DURABILITY) + uint256(_calculate(_x)) / 8192, uint256(MAX_DURABILITY)));
    }

    function duration(uint256, uint64 _x) external pure returns (uint64 _y) {
        return uint64(
            _min(
                uint256(MIN_DURATION) + uint256(_x) * uint256(MAX_DURATION) / uint256(type(uint64).max),
                uint256(MAX_DURATION)
            )
        );
    }

    function _rarityCoefficient(uint256 _tokenId) internal pure returns (uint16 c) {
        if (_tokenId < 100) {
            return 7;
        }
        if (_tokenId < 1000) {
            return 3;
        }

        c = 1;
        if (_tokenId % 100 == 0) {
            c += 1;
        }
        if (_tokenId % 1000 == 0) {
            c += 2;
        }
        if (_tokenId % 10_000 == 0) {
            c += 3;
        }
        if (_tokenId % 100_000 == 0) {
            c += 4;
        }
        if (_tokenId % 1_000_000 == 0) {
            c += 5;
        }
        if (_tokenId % 10_000_000 == 0) {
            c += 6;
        }
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }

    function _calculate(uint16 _x) internal pure returns (uint16 _y) {
        // 88.8%, 99.9%, 100% of type(uint16).max, respectively
        uint256[3] memory x_points = [uint256(58_196), uint256(65_470), uint256(65_535)];
        // 8.88%, 33.3%, 100% of 10000, respectively
        uint256[3] memory y_points = [uint256(888), uint256(3330), uint256(10_000)];

        if (_x <= x_points[0]) {
            _y = uint16((_x * y_points[0]) / x_points[0]);
        } else if (_x <= x_points[1]) {
            _y = uint16(((y_points[1] - y_points[0]) * (_x - x_points[0])) / (x_points[1] - x_points[0]) + y_points[0]);
        } else {
            _y = uint16(((y_points[2] - y_points[1]) * (_x - x_points[1])) / (x_points[2] - x_points[1]) + y_points[1]);
        }
    }
}
