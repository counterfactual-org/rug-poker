// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface INFT {
    function minter() external view returns (address);

    function nextTokenId() external view returns (uint256);

    function dataOf(uint256 id) external view returns (bytes32);

    function mintWithData(address to, bytes32 value) external;

    function burn(uint256 id) external;
}
