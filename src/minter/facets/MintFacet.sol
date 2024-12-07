// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { SHARES_GAME, SHARES_TREASURY } from "../MinterConstants.sol";

import { ReferralCodeInfo } from "../MinterStorage.sol";
import { MinterConfig, MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseMinterFacet } from "./BaseMinterFacet.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract MintFacet is BaseMinterFacet {
    bytes26 constant ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    event IncreaseBogo(address indexed account, uint256 count);
    event Mint(uint256 price, uint256 amount, uint256 bonus, bool useBogo, address indexed to);
    event IssueReferralCode(address indexed account, string indexed referralCode);

    error Forbidden();
    error InsufficientBogo();
    error InvalidValue();
    error DuplicateReferralCode();
    error InvalidReferralCode();
    error ReferralCodeIssued();
    error FailedToIssueReferralCode();

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](12);
        s[0] = this.bogoOf.selector;
        s[1] = this.increaseBogoOf.selector;
        s[2] = this.mintableFreeCardsOf.selector;
        s[3] = this.mint.selector;
        s[4] = this.mintWithReferralCode.selector;
        s[5] = this.mintFree.selector;
        s[6] = this.mintBogo.selector;
        s[7] = this.isAirdrop.selector;
        s[8] = this.airdrop.selector;
        s[9] = this.referralCodeOf.selector;
        s[10] = this.referralCodeInfo.selector;
        s[11] = this.issueReferralCode.selector;
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

    function mintableFreeCardsOf(address account) public view returns (uint256 cards) {
        string memory referralCode = s.referralCodes[account];
        if (bytes(referralCode).length > 0) {
            ReferralCodeInfo memory info = s.referralCodeInfo[referralCode];
            uint256 freeCards = info.used / 5;
            return freeCards > info.freeCardsMinted ? freeCards - info.freeCardsMinted : 0;
        }
    }

    function mint(uint256 amount) external payable {
        _mint(amount, false, "");
    }

    function mintWithReferralCode(uint256 amount, string memory referralCode) external payable {
        _mint(amount, false, referralCode);
    }

    function mintFree() external {
        string memory referralCode = s.referralCodes[msg.sender];
        if (bytes(referralCode).length == 0) return;

        uint256 freeCards = mintableFreeCardsOf(msg.sender);
        s.referralCodeInfo[referralCode].freeCardsMinted += freeCards;

        INFT nft = MinterConfigs.nft();
        for (uint256 i; i < freeCards; ++i) {
            _mintOne(nft, msg.sender);
        }
    }

    function mintBogo() external payable {
        _mint(1, true, "");
    }

    function _mint(uint256 amount, bool useBogo, string memory referralCode) internal {
        if (useBogo) {
            uint256 bogo = s.bogo[msg.sender];
            if (bogo == 0) revert InsufficientBogo();
            s.bogo[msg.sender] = bogo - 1;
        }

        uint8 discountPercentage = 10;
        if (bytes(referralCode).length > 0) {
            ReferralCodeInfo storage info = s.referralCodeInfo[referralCode];
            if (info.owner == address(0) || info.owner == msg.sender) revert InvalidReferralCode();
            info.used += 1;
            discountPercentage += 20;
        }

        MinterConfig memory c = MinterConfigs.latest();
        uint256 totalPrice = amount * c.price * (100 - discountPercentage) / 100;
        if (msg.value != totalPrice) revert InvalidValue();

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

    function referralCodeOf(address account) external view returns (string memory) {
        return s.referralCodes[account];
    }

    function referralCodeInfo(string memory referralCode) external view returns (ReferralCodeInfo memory) {
        return s.referralCodeInfo[referralCode];
    }

    function issueReferralCode(string memory code) external {
        if (bytes(s.referralCodes[msg.sender]).length > 0) revert ReferralCodeIssued();
        if (s.referralCodeInfo[code].owner != address(0)) revert DuplicateReferralCode();

        uint256 length = bytes(code).length;
        if (length < 4 || length > 8) revert InvalidReferralCode();
        for (uint256 i; i < length; ++i) {
            if (!_isAlphabet(bytes(code)[i])) revert InvalidReferralCode();
        }

        s.referralCodes[msg.sender] = code;
        s.referralCodeInfo[code] = ReferralCodeInfo(msg.sender, 0, 0);

        emit IssueReferralCode(msg.sender, code);
    }

    function _isAlphabet(bytes1 b) internal pure returns (bool) {
        for (uint256 i; i < 26; ++i) {
            if (ALPHABET[i] == b) return true;
        }
        return false;
    }
}
