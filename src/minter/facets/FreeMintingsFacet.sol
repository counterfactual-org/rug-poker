// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { BaseFacet } from "./BaseFacet.sol";

contract FreeMintingsFacet is BaseFacet {
    error Forbidden();

    event IncreaseFreeMintingOf(address indexed account, uint256 count);

    function freeMintingOf(address account) external view returns (uint256) {
        return s.freeMintingOf[account];
    }

    function increaseFreeMintingOf(address account) external {
        if (msg.sender != s.game) revert Forbidden();

        uint256 freeMinting = s.freeMintingOf[account];
        s.freeMintingOf[account] = freeMinting + 1;

        emit IncreaseFreeMintingOf(account, freeMinting + 1);
    }
}
