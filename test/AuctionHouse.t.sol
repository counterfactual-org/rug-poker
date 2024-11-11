// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { MockERC721 } from "forge-std/mocks/MockERC721.sol";

import { AuctionHouse } from "src/AuctionHouse.sol";

contract MockNFT is MockERC721 {
    constructor() {
        initialize("NFT", "NFT");
    }

    function mint(address to, uint256 id) public virtual {
        _mint(to, id);
    }
}

contract AuctionHouseTest is Test {
    uint256 public DRAW_PRICE = 0.01e18;
    uint64 public AUCTION_EXTENSION = 10 minutes;
    uint64 public DURATION_MIN = 3 hours;
    uint128 public PRICE_MIN = 0.1e18;

    address private owner = makeAddr("owner");
    address private treasury = makeAddr("treasury");
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    MockNFT private nft;
    AuctionHouse private house;

    event Draw(uint256 indexed tokenId, uint256 indexed randomNumberId);
    event Mint(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed randomNumberId,
        uint16 factor,
        uint16 durability,
        uint64 duration
    );
    event StartAuction(uint256 indexed id, address indexed owner, uint64 deadline, uint128 priceMin);
    event EndAuction(uint256 indexed id, address indexed owner, bool indexed bidPlaced);
    event Bid(uint256 indexed id, address indexed owner, address indexed bidder, uint128 price);
    event TransferETH(address indexed to, uint256 amount);

    error Forbidden();
    error InvalidAddress();
    error InvalidDrawPrice();
    error DrawPriceCannotCoverFee();
    error InvalidDurationMin();
    error InvalidDeadline();
    error InvalidPriceMin();
    error InvalidShares();
    error InvalidPrice();
    error AuctionInProgress();
    error Expired();
    error NotOpenAuction();
    error BidPlaced();
    error Underpriced();
    error TransferFailed();

    function setUp() public {
        nft = new MockNFT();
        house = new AuctionHouse(address(nft), treasury, owner);

        vm.deal(alice, 10_000e18);
        vm.deal(bob, 10_000e18);
        vm.deal(charlie, 10_000e18);

        changePrank(alice, alice);
        nft.mint(alice, 0);
        nft.approve(address(house), 0);
    }

    function test_updateTreasury_revertInvalidAddress() public {
        changePrank(owner, owner);

        vm.expectRevert(InvalidAddress.selector);
        house.updateTreasury(address(0));
    }

    function test_updateTreasury() public {
        changePrank(owner, owner);

        house.updateTreasury(owner);

        assertEq(house.treasury(), owner);
    }

    function test_updateAuctionDurationMin_revertUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        house.updateAuctionDurationMin(0);
    }

    function test_updateAuctionDurationMin_revertInvalidAuctionDurationMin() public {
        changePrank(owner, owner);

        vm.expectRevert(InvalidDurationMin.selector);
        house.updateAuctionDurationMin(1 hours - 1);
    }

    function test_updateAuctionDurationMin() public {
        changePrank(owner, owner);

        house.updateAuctionDurationMin(1 days);

        assertEq(house.auctionDurationMin(), 1 days);
    }

    function test_updateAuctionPriceMin_revertUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        house.updateAuctionPriceMin(0);
    }

    function test_updateAuctionPriceMin_revertInvalidPriceMin() public {
        changePrank(owner, owner);

        vm.expectRevert(InvalidPriceMin.selector);
        house.updateAuctionPriceMin(0);
    }

    function test_updateAuctionPriceMin() public {
        changePrank(owner, owner);

        house.updateAuctionPriceMin(1 days);

        assertEq(house.auctionPriceMin(), 1 days);
    }

    function test_updateTreasuryShares_revertUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        house.updateTreasuryShares(0);
    }

    function test_updateTreasuryShares() public {
        changePrank(owner, owner);

        house.updateTreasuryShares(10_000);

        assertEq(house.treasuryShares(), 10_000);

        house.updateTreasuryShares(0);

        assertEq(house.treasuryShares(), 0);
    }

    function test_startAuction_revertInvalidDeadline() public {
        vm.expectRevert(InvalidDeadline.selector);
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN - 1), PRICE_MIN);
    }

    function test_startAuction_revertInvalidPriceMin() public {
        vm.expectRevert(InvalidPriceMin.selector);
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN), PRICE_MIN - 1);
    }

    function test_startAuction_revertForbidden() public {
        changePrank(bob, bob);
        vm.expectRevert(Forbidden.selector);
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN), PRICE_MIN);
    }

    function test_startAuction() public {
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);

        uint64 deadline = uint64(block.timestamp + DURATION_MIN);

        vm.expectEmit();
        emit StartAuction(0, alice, deadline, PRICE_MIN);
        house.startAuction(0, deadline, PRICE_MIN);

        (uint64 _deadline, address _bidder, uint128 _priceMin, uint128 _bidHighest) = house.openAuctionOf(0, alice);

        assertEq(_deadline, deadline);
        assertEq(_bidder, address(0));
        assertEq(_priceMin, PRICE_MIN);
        assertEq(_bidHighest, 0);

        assertEq(nft.ownerOf(0), address(house));
        assertEq(nft.balanceOf(alice), 0);
    }

    function test_endMyAuction_revertNotOpenAuction() public {
        vm.expectRevert(NotOpenAuction.selector);
        house.endMyAuction(0);
    }

    function test_endMyAuction_revertBidPlaced() public {
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN), PRICE_MIN);

        changePrank(bob, bob);
        house.bid{ value: 1e18 }(0, alice);

        changePrank(alice, alice);
        vm.expectRevert(BidPlaced.selector);
        house.endMyAuction(0);
    }

    function test_endAuction_revertNotOpenAuction() public {
        vm.expectRevert(NotOpenAuction.selector);
        house.endAuction(0, alice);
    }

    function test_endAuction_revertAuctionInProgress() public {
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN), PRICE_MIN);

        vm.expectRevert(AuctionInProgress.selector);
        house.endAuction(0, alice);
    }

    function test_endAuction_whenBidPlaced() public {
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN), PRICE_MIN);

        assertEq(nft.ownerOf(0), address(house));
        assertEq(nft.balanceOf(alice), 0);

        changePrank(bob, bob);
        house.bid{ value: 1e18 }(0, alice);

        skip(DURATION_MIN + 1);

        uint256 balanceTreasury = treasury.balance;
        uint256 balanceAlice = alice.balance;

        vm.expectEmit();
        emit EndAuction(0, alice, true);
        house.endAuction(0, alice);

        assertEq(nft.ownerOf(0), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);

        assertEq(treasury.balance - balanceTreasury, 0.3e18);
        assertEq(alice.balance - balanceAlice, 0.7e18);
    }

    function test_endAuction_whenBidNotPlaced() public {
        house.startAuction(0, uint64(block.timestamp + DURATION_MIN), PRICE_MIN);

        assertEq(nft.ownerOf(0), address(house));
        assertEq(nft.balanceOf(alice), 0);

        skip(DURATION_MIN + 1);

        vm.expectEmit();
        emit EndAuction(0, alice, false);
        house.endAuction(0, alice);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_bid_revertNotOpenAuction() public {
        vm.expectRevert(NotOpenAuction.selector);
        house.bid(0, alice);
    }

    function test_bid_revertExpired() public {
        uint64 deadline = uint64(block.timestamp + DURATION_MIN);
        house.startAuction(0, deadline, PRICE_MIN);

        skip(DURATION_MIN + 1);
        changePrank(bob, bob);

        vm.expectRevert(Expired.selector);
        house.bid(0, alice);
    }

    function test_bid_revertInvalidPrice() public {
        uint64 deadline = uint64(block.timestamp + DURATION_MIN);
        house.startAuction(0, deadline, PRICE_MIN);

        changePrank(bob, bob);

        vm.expectRevert(InvalidPrice.selector);
        house.bid(0, alice);
    }

    function test_bid_revertUnderpriced() public {
        uint64 deadline = uint64(block.timestamp + DURATION_MIN);
        house.startAuction(0, deadline, PRICE_MIN);

        changePrank(bob, bob);

        house.bid{ value: 1e18 }(0, alice);

        vm.expectRevert(Underpriced.selector);
        house.bid{ value: 1e18 }(0, alice);
    }

    function test_bid() public {
        uint64 deadline = uint64(block.timestamp + DURATION_MIN);
        house.startAuction(0, deadline, PRICE_MIN);

        changePrank(bob, bob);

        uint256 balanceBob = bob.balance;

        vm.expectEmit();
        emit Bid(0, alice, bob, 1e18);
        house.bid{ value: 1e18 }(0, alice);

        (uint64 _deadline, address _bidder,, uint128 _bidHighest) = house.openAuctionOf(0, alice);
        assertEq(_bidder, bob);
        assertEq(_bidHighest, 1e18);
        assertEq(balanceBob - bob.balance, 1e18);

        vm.warp(_deadline - 1);

        changePrank(charlie, charlie);

        balanceBob = bob.balance;

        uint64 newDeadline = uint64(block.timestamp + AUCTION_EXTENSION);
        vm.expectEmit();
        emit Bid(0, alice, charlie, 2e18);
        house.bid{ value: 2e18 }(0, alice);

        (_deadline, _bidder,, _bidHighest) = house.openAuctionOf(0, alice);
        assertEq(_deadline, newDeadline);
        assertEq(_bidder, charlie);
        assertEq(_bidHighest, 2e18);
        assertEq(bob.balance - balanceBob, 1e18);
    }
}
