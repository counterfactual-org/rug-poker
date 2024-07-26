// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IRandomizer {
    // Makes a Randomizer VRF callback request with a callback gas limit
    function request(uint256 callbackGasLimit) external returns (uint256);

    // Estimates the VRF fee given a callback gas limit
    function estimateFee(uint256 callbackGasLimit) external view returns (uint256);

    // Deposits ETH to Randomizer for the client contract
    function clientDeposit(address client) external payable;

    // Withdraws deposited ETH from the client contract to the destination address
    function clientWithdrawTo(address to, uint256 amount) external;

    function getFeeStats(uint256 request) external view returns (uint256[2] memory);

    // Gets the amount of ETH deposited and reserved for the client contract
    function clientBalanceOf(address _client) external view returns (uint256 deposit, uint256 reserved);

    // Returns the request data
    function getRequest(uint256 request)
        external
        view
        returns (bytes32 result, bytes32 dataHash, uint256 ethPaid, uint256 ethRefunded, bytes10[2] memory vrfHashes);
}
