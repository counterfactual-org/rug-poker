// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ERC1155Lib } from "src/libraries/ERC1155Lib.sol";

library Items {
    error InsufficientItem();

    function spend(uint256 id, address owner) internal {
        if (ERC1155Lib.erc1155Storage().balanceOf[owner][id] == 0) revert InsufficientItem();

        ERC1155Lib.burn(owner, id, 1);
    }
}
