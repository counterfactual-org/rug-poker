// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface IJackpot {
    function prize() external view returns (uint256);

    function drawWinner() external;
}
