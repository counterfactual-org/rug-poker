// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseFacet } from "./BaseFacet.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract JackpotFacet is BaseFacet {
    event WinnerDrawn(uint256 indexed batchId, uint256 rank, address indexed winner);

    function jackpot() public view returns (uint256) {
        return address(this).balance;
    }

    function batchId() external view returns (uint256) {
        return s.batchId;
    }

    function onMint(uint256 tokenId, uint256 amount, address) external {
        uint256 _batchId = (tokenId + amount - 1) / s.tokensInBatch;
        if (_batchId <= s.batchId) return;
        s.batchId = _batchId;

        uint256 prize = jackpot();
        if (prize == 0) return;

        bytes32 data = MinterConfigs.nft().dataOf(tokenId);
        uint256 offset = s.entrantsOffset;
        uint256 size = s.entrants.length - offset;
        uint8[] memory winnerRatios = MinterConfigs.latest().winnerRatios;
        for (uint256 i; i < winnerRatios.length; ++i) {
            data = keccak256(abi.encodePacked(data, i));
            address winner = s.entrants[offset + uint256(data) % size];
            TransferLib.transferETH(winner, prize * winnerRatios[i] / 100, address(this));

            emit WinnerDrawn(_batchId, i, winner);
        }

        s.entrantsOffset = s.entrants.length;
    }
}
