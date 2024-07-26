// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface INFTMinter {
    function increaseFreeMintingOf(address account) external;

    function mint(uint256 amount) external payable;

    function onMint(uint256 tokenId, uint256 amount, address to) external;
}
