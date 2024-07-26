// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Owned } from "solmate/auth/Owned.sol";

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";

contract AuctionHouse is Owned, ReentrancyGuard {
    struct Auction {
        uint64 deadline;
        address bidder;
        uint128 priceMin;
        uint128 bidHighest;
    }

    address public immutable nft;
    address public treasury;

    uint128 public auctionPriceMin = 0.1e18;
    uint64 public auctionDurationMin = 3 hours;
    uint64 public auctionExtension = 10 minutes;
    uint16 public treasuryShares = 3000; // bps

    mapping(uint256 id => mapping(address owner => Auction)) public openAuctionOf;

    event UpdateTreasury(address indexed treasury);
    event UpdateAuctionPriceMin(uint128 priceMin);
    event UpdateAuctionDurationMin(uint64 durationMin);
    event UpdateAuctionExtension(uint64 extension);
    event UpdateTreasuryShares(uint16 shares);
    event StartAuction(uint256 indexed id, address indexed owner, uint64 deadline, uint128 priceMin);
    event EndAuction(uint256 indexed id, address indexed owner, bool indexed bidPlaced);
    event Bid(uint256 indexed id, address indexed owner, address indexed bidder, uint128 price);

    error Forbidden();
    error InvalidAddress();
    error InvalidPriceMin();
    error InvalidDurationMin();
    error InvalidDeadline();
    error InvalidPrice();
    error AuctionInProgress();
    error Expired();
    error NotOpenAuction();
    error BidPlaced();
    error Underpriced();

    constructor(address _nft, address _treasury, address _owner) Owned(_owner) {
        nft = _nft;
        treasury = _treasury;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert InvalidAddress();

        treasury = _treasury;

        emit UpdateTreasury(_treasury);
    }

    function updateAuctionPriceMin(uint128 priceMin) external onlyOwner {
        if (priceMin == 0) revert InvalidPriceMin();

        auctionPriceMin = priceMin;

        emit UpdateAuctionPriceMin(priceMin);
    }

    function updateAuctionDurationMin(uint64 durationMin) external onlyOwner {
        if (durationMin < 1 hours) revert InvalidDurationMin();

        auctionDurationMin = durationMin;

        emit UpdateAuctionDurationMin(durationMin);
    }

    function updateAuctionExtension(uint64 extension) external onlyOwner {
        auctionExtension = extension;

        emit UpdateAuctionExtension(extension);
    }

    function updateTreasuryShares(uint16 shares) external onlyOwner {
        treasuryShares = shares;

        emit UpdateTreasuryShares(shares);
    }

    function startAuction(uint256 id, uint64 deadline, uint128 priceMin) external nonReentrant {
        if (deadline < uint64(block.timestamp + auctionDurationMin)) revert InvalidDeadline();
        if (priceMin < auctionPriceMin) revert InvalidPriceMin();
        if (msg.sender != IERC721(nft).ownerOf(id)) revert Forbidden();

        openAuctionOf[id][msg.sender] = Auction(deadline, address(0), priceMin, 0);

        IERC721(nft).transferFrom(msg.sender, address(this), id);

        emit StartAuction(id, msg.sender, deadline, priceMin);
    }

    function endMyAuction(uint256 id) external nonReentrant {
        Auction memory auction = openAuctionOf[id][msg.sender];
        if (auction.deadline == 0) revert NotOpenAuction();
        if (auction.bidder != address(0) && auction.bidHighest > 0) revert BidPlaced();

        _endAuction(id, owner, auction.bidder, auction.bidHighest);
    }

    function endAuction(uint256 id, address owner) external nonReentrant {
        Auction memory auction = openAuctionOf[id][owner];
        if (auction.deadline == 0) revert NotOpenAuction();
        if (block.timestamp < auction.deadline) revert AuctionInProgress();

        _endAuction(id, owner, auction.bidder, auction.bidHighest);
    }

    function _endAuction(uint256 id, address owner, address bidder, uint128 bidHighest) internal {
        bool bidPlaced = bidder != address(0) && bidHighest > 0;
        if (bidPlaced) {
            uint256 amountTreasury = bidHighest * treasuryShares / 10_000;
            TransferLib.transferETH(owner, bidHighest - amountTreasury, treasury);
            TransferLib.transferETH(treasury, amountTreasury, address(0));

            IERC721(nft).transferFrom(address(this), bidder, id);
        } else {
            IERC721(nft).transferFrom(address(this), owner, id);
        }

        delete openAuctionOf[id][owner];

        emit EndAuction(id, owner, bidPlaced);
    }

    function bid(uint256 id, address owner) external payable {
        Auction storage auction = openAuctionOf[id][owner];
        (uint64 deadline, address bidder, uint128 bidHighest) = (auction.deadline, auction.bidder, auction.bidHighest);
        if (deadline == 0) revert NotOpenAuction();
        if (deadline < block.timestamp) revert Expired();

        uint128 price = uint128(msg.value);
        if (price < auction.priceMin) revert InvalidPrice();
        if (bidHighest != 0 && price <= bidHighest) revert Underpriced();

        if (deadline - block.timestamp < auctionExtension) {
            auction.deadline = uint64(block.timestamp + auctionExtension);
        }
        auction.bidder = msg.sender;
        auction.bidHighest = price;

        if (bidder != address(0) && bidHighest != 0) {
            TransferLib.transferETH(bidder, bidHighest, treasury);
        }

        emit Bid(id, owner, msg.sender, price);
    }
}
