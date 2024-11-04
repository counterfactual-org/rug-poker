// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseMinterFacet } from "./BaseMinterFacet.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract JackpotFacet is BaseMinterFacet {
    event WinnerDrawn(uint256 indexed batchId, uint256 rank, address indexed winner, uint8 ratio, uint256 prize);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](6);
        s[0] = this.jackpot.selector;
        s[1] = this.batchId.selector;
        s[2] = this.entrantsOffset.selector;
        s[3] = this.entrantsLength.selector;
        s[4] = this.entrants.selector;
        s[5] = this.onMint.selector;
    }

    function jackpot() public view returns (uint256) {
        return address(this).balance;
    }

    function batchId() external view returns (uint256) {
        return s.batchId;
    }

    function entrantsOffset() external view returns (uint256) {
        return s.entrantsOffset;
    }

    function entrantsLength() external view returns (uint256) {
        return s.entrants.length;
    }

    function entrants(uint256 i) external view returns (address) {
        return s.entrants[i];
    }

    function onMint(uint256 tokenId, uint256 amount, address) external {
        uint256 _batchId = (tokenId + amount - 1) / s.tokensInBatch;
        if (_batchId <= s.batchId) return;
        s.batchId = _batchId;

        uint256 totalPrice = jackpot();
        if (totalPrice == 0) return;

        bytes32 data = MinterConfigs.nft().dataOf(tokenId);
        uint256 offset = s.entrantsOffset;
        uint256 size = s.entrants.length - offset;
        uint8[] memory winnerRatios = MinterConfigs.latest().winnerRatios;
        for (uint256 i; i < winnerRatios.length; ++i) {
            data = keccak256(abi.encodePacked(data, i));
            address winner = s.entrants[offset + uint256(data) % size];
            uint256 prize = totalPrice * winnerRatios[i] / 100;
            TransferLib.transferETH(winner, prize, address(this));

            emit WinnerDrawn(_batchId, i, winner, winnerRatios[i], prize);
        }

        s.entrantsOffset = s.entrants.length;
    }
}
