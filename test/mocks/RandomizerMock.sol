// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRandomizer } from "src/interfaces/IRandomizer.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";

contract RandomizerMock is IRandomizer {
    struct Request {
        uint256 fee;
        address client;
    }

    error EthDepositTooLow();
    error WithdrawingTooMuch();

    mapping(uint256 id => Request) public pendingRequests;
    mapping(address client => uint256) public ethDeposit;
    mapping(address client => uint256) public ethReserved;

    uint256 private _estimateFee;
    uint256 private lastId;

    function request(uint256) external returns (uint256 id) {
        uint256 deposit = ethDeposit[msg.sender];
        uint256 reserved = ethReserved[msg.sender];
        if (deposit < reserved || _estimateFee > (deposit - reserved)) {
            revert EthDepositTooLow();
        }

        ethReserved[msg.sender] += _estimateFee;

        id = lastId++;
        pendingRequests[id] = Request(_estimateFee, msg.sender);
    }

    function processPendingRequest(uint256 id, bytes32 value) external {
        Request memory pending = pendingRequests[id];
        if (pending.client == address(0)) revert("Request is not pending");

        IRandomizerCallback(pending.client).randomizerCallback(id, value);
    }

    function estimateFee(uint256) external view returns (uint256) {
        return _estimateFee;
    }

    function setEstimateFee(uint256 fee) public {
        _estimateFee = fee;
    }

    function clientDeposit(address client) external payable {
        ethDeposit[client] += msg.value;
    }

    function clientWithdrawTo(address to, uint256 amount) external {
        if (amount > ethDeposit[msg.sender] - ethReserved[msg.sender]) {
            revert WithdrawingTooMuch();
        }
        ethDeposit[msg.sender] -= amount;
        (bool ok,) = to.call{ value: amount }("");
        require(ok, "TRANSFER_FAILED");
    }

    function getFeeStats(uint256) external pure returns (uint256[2] memory feeStats) {
        return feeStats;
    }

    function clientBalanceOf(address client) external view returns (uint256 deposit, uint256 reserved) {
        return (ethDeposit[client], ethReserved[client]);
    }

    function getRequest(uint256)
        external
        pure
        returns (bytes32 result, bytes32 dataHash, uint256 ethPaid, uint256 ethRefunded, bytes10[2] memory vrfHashes)
    {
        return (bytes32(0), bytes32(0), 0, 0, vrfHashes);
    }
}
