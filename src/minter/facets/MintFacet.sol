// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { SHARES_GAME, SHARES_TREASURY } from "../MinterConstants.sol";
import { MinterConfig, MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseMinterFacet } from "./BaseMinterFacet.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract MintFacet is BaseMinterFacet {
    event IncreaseBogo(address indexed account, uint256 count);
    event Mint(uint256 price, uint256 amount, uint256 bonus, bool useBogo, address indexed to);

    error Forbidden();
    error InsufficientBogo();
    error InsufficientValue();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](6);
        s[0] = this.bogoOf.selector;
        s[1] = this.increaseBogoOf.selector;
        s[2] = this.mint.selector;
        s[3] = this.mintBogo.selector;
        s[4] = this.isAirdrop.selector;
        s[5] = this.airdrop.selector;
    }

    function isAirdrop(uint256) external pure returns (bool) {
        return false;
    }

    function bogoOf(address account) external view returns (uint256) {
        return s.bogo[account];
    }

    function increaseBogoOf(address account) external {
        if (msg.sender != s.game) revert Forbidden();

        uint256 free = s.bogo[account] + 1;
        s.bogo[account] = free;

        emit IncreaseBogo(account, free);
    }

    function mint(uint256 amount) external payable {
        _mint(amount, false);
    }

    function mintBogo() external payable {
        _mint(1, true);
    }

    function _mint(uint256 amount, bool useBogo) internal {
        if (useBogo) {
            uint256 bogo = s.bogo[msg.sender];
            if (bogo == 0) revert InsufficientBogo();
            s.bogo[msg.sender] = bogo - 1;
        }

        MinterConfig memory c = MinterConfigs.latest();
        uint256 totalPrice = amount * c.price;
        if (block.timestamp < c.initialDiscountUntil) {
            totalPrice = totalPrice * 7 / 10;
        }
        if (msg.value != totalPrice) revert InsufficientValue();

        TransferLib.transferETH(s.treasury, totalPrice * c.shares[SHARES_TREASURY] / 100, address(0));
        TransferLib.transferETH(s.game, totalPrice * c.shares[SHARES_GAME] / 100, address(0));

        for (uint256 i; i < amount; ++i) {
            s.entrants.push(msg.sender);
        }

        uint256 bonus = (amount >= 10 ? 5 : amount >= 5 ? 2 : amount >= 3 ? 1 : 0);
        uint256 totalAmount = amount + bonus + (useBogo ? 1 : 0);
        INFT nft = MinterConfigs.nft();
        for (uint256 i; i < totalAmount; ++i) {
            _mintOne(nft, msg.sender);
        }

        emit Mint(totalPrice, amount, bonus, useBogo, msg.sender);
    }

    function airdrop(bytes calldata accounts, uint8 size) external onlyOwner {
        INFT nft = MinterConfigs.nft();
        uint256 length = accounts.length / 20;
        for (uint256 i; i < length; ++i) {
            address account = address(bytes20(accounts[i * 20:i * 20 + 20]));
            for (uint256 j; j < size; ++j) {
                _mintOne(nft, account);
            }
        }
    }

    function _mintOne(INFT nft, address to) internal {
        // TODO: turn on vrf later
        nft.mintWithData(to, keccak256(abi.encodePacked(block.number, block.timestamp, tx.gasprice, gasleft())));
    }
}
