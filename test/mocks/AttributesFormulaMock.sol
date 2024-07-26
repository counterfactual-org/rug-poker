// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IAttributesFormula } from "src/interfaces/IAttributesFormula.sol";

contract AttributesFormulaMock is IAttributesFormula {
    uint16 public constant MIN_MULTIPLIER = 10_000;
    uint16 public constant MAX_MULTIPLIER = 20_000;
    uint16 public constant MIN_DURABILITY = 1;
    uint16 public constant MAX_DURABILITY = 8;
    uint64 public constant MIN_DURATION = 1 weeks;
    uint64 public constant MAX_DURATION = 52 weeks;

    uint16 private _multiplier;
    uint16 private _durability;
    uint64 private _duration;

    function setMultiplier(uint16 _y) external {
        _multiplier = _y;
    }

    function setDurability(uint16 _y) external {
        _durability = _y;
    }

    function setDuration(uint64 _y) external {
        _duration = _y;
    }

    function multiplier(uint256, uint16) external view returns (uint16 _y) {
        return _multiplier;
    }

    function durability(uint256, uint16) external view returns (uint16 _y) {
        return _durability;
    }

    function duration(uint256, uint64) external view returns (uint64 _y) {
        return _duration;
    }
}
