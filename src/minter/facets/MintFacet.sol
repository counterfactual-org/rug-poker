// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { SHARES_GAME, SHARES_TREASURY } from "../MinterConstants.sol";
import { MinterConfig, MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract MintFacet is BaseFacet {
    event Mint(uint256 price, uint256 amount, uint256 bonus, bool freeMint, address indexed to);

    error InsufficientFreeMinting();
    error FreeMintingNotAvailable();
    error InsufficientValue();

    function mint(uint256 amount) external payable {
        mint(amount, false);
    }

    function mint(uint256 amount, bool freeMint) public payable {
        if (freeMint) {
            uint256 freeMinting = s.freeMintingOf[msg.sender];
            if (freeMinting == 0) revert InsufficientFreeMinting();
            if (amount != 1) revert FreeMintingNotAvailable();
            s.freeMintingOf[msg.sender] = freeMinting - 1;
        }

        MinterConfig memory c = MinterConfigs.latest();
        uint256 rate = (amount >= 10) ? 80 : (amount >= 5) ? 88 : 100;
        uint256 totalPrice = amount * c.price * rate / 100;
        if (msg.value < totalPrice) revert InsufficientValue();

        TransferLib.transferETH(s.treasury, totalPrice * c.shares[SHARES_TREASURY] / 100, address(0));
        TransferLib.transferETH(s.game, totalPrice * c.shares[SHARES_GAME] / 100, address(0));

        for (uint256 i; i < amount; ++i) {
            s.entrants.push(msg.sender);
        }

        uint256 bonus = block.timestamp < c.initialBonusUntil ? (amount >= 10 ? 5 : amount >= 5 ? 2 : 0) : 0;
        INFT nft = MinterConfigs.nft();
        INFT(nft).draw{ value: INFT(nft).estimateRandomizerFee() }(amount + bonus + (freeMint ? 1 : 0), msg.sender);

        emit Mint(totalPrice, amount, bonus, freeMint, msg.sender);
    }
}
