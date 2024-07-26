// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

library TransferLib {
    event TransferETH(address indexed to, uint256 amount);

    error TransferFailed();

    function transferETH(address to, uint256 amount, address _fallback) internal returns (bool ok) {
        (ok,) = to.call{ value: amount }("");
        if (ok) {
            emit TransferETH(to, amount);
        } else if (_fallback != address(0)) {
            transferETH(_fallback, amount, address(0));
            emit TransferETH(_fallback, amount);
        } else {
            revert TransferFailed();
        }
    }
}
