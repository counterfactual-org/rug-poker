// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISvgRenderer {
    function render(uint256 tokenId) external view returns (bytes memory svg);
}
