// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface IAttributesFormula {
    function MIN_MULTIPLIER() external view returns (uint16);

    function MAX_MULTIPLIER() external view returns (uint16);

    function MIN_DURABILITY() external view returns (uint16);

    function MAX_DURABILITY() external view returns (uint16);

    function MIN_DURATION() external view returns (uint64);

    function MAX_DURATION() external view returns (uint64);

    function multiplier(uint256 _tokenId, uint16 _x) external view returns (uint16 _y);

    function durability(uint256 _tokenId, uint16 _x) external view returns (uint16 _y);

    function duration(uint256 _tokenId, uint64 _x) external view returns (uint64 _y);
}
