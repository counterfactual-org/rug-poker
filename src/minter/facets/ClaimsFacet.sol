// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { MinterConfig, MinterConfigs } from "../models/MinterConfigs.sol";
import { BaseMinterFacet } from "./BaseMinterFacet.sol";

import { MerkleProofLib } from "solmate/utils/MerkleProofLib.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";

contract ClaimsFacet is BaseMinterFacet {
    error ClaimUnavailable();
    error InvalidMerkleRoot();
    error InvalidMerkleProof();
    error AlreadyClaimed();

    event UpdateMerkleRoot(bytes32 indexed merkleRoot, bool isMerkleRoot);
    event Claim(bytes32 indexed merkleRoot, address indexed account, uint256 indexed tokenId, uint256 amount);

    function selectors() external pure override returns (bytes4[] memory s) {
        s = new bytes4[](6);
        s[0] = this.isMerkleRoot.selector;
        s[1] = this.hasClaimed.selector;
        s[2] = this.totalClaimed.selector;
        s[3] = this.isAirdrop.selector;
        s[4] = this.updateMerkleRoot.selector;
        s[5] = this.claim.selector;
    }

    function isMerkleRoot(bytes32 merkleRoot) external view returns (bool) {
        return s.isMerkleRoot[merkleRoot];
    }

    function hasClaimed(bytes32 merkleRoot, address account) external view returns (bool) {
        return s.hasClaimed[merkleRoot][account];
    }

    function totalClaimed(bytes32 merkleRoot) external view returns (uint256) {
        return s.totalClaimed[merkleRoot];
    }

    function isAirdrop(uint256 tokenId) external view returns (bool) {
        return s.isAirdrop[tokenId];
    }

    function updateMerkleRoot(bytes32 merkleRoot, bool _isMerkleRoot) external onlyOwner {
        s.isMerkleRoot[merkleRoot] = _isMerkleRoot;

        emit UpdateMerkleRoot(merkleRoot, _isMerkleRoot);
    }

    function claim(bytes32 merkleRoot, bytes32[] calldata proof, uint256 amount) external payable {
        uint256 _totalClaimed = s.totalClaimed[merkleRoot] + amount;
        if (_totalClaimed < MinterConfigs.latest().claimLimit) revert ClaimUnavailable();
        if (!s.isMerkleRoot[merkleRoot]) revert InvalidMerkleRoot();
        if (s.hasClaimed[merkleRoot][msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        bool isValidProof = MerkleProofLib.verify(proof, merkleRoot, leaf);
        if (!isValidProof) revert InvalidMerkleProof();

        s.hasClaimed[merkleRoot][msg.sender] = true;
        s.totalClaimed[merkleRoot] = _totalClaimed;

        INFT nft = MinterConfigs.nft();
        uint256 tokenId = nft.nextTokenId();
        for (uint256 i; i < amount; ++i) {
            s.isAirdrop[tokenId + i] = true;
        }

        nft.draw{ value: INFT(nft).estimateRandomizerFee() }(amount, msg.sender);

        emit Claim(merkleRoot, msg.sender, tokenId, amount);
    }
}
