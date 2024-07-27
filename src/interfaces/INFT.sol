// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface INFT {
    function minter() external view returns (address);

    function nextTokenId() external view returns (uint256);

    function dataOf(uint256 id) external view returns (bytes32);

    function isAirdrop(uint256 id) external view returns (bool);

    function estimateRandomizerFee() external view returns (uint256);

    function updateData(uint256 id, bytes32 data) external;

    function draw(uint256 amount, address to, bool airdrop) external payable;

    function burn(uint256 id) external;
}
