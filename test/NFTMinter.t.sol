// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GameMock } from "./mocks/GameMock.sol";
import { RandomizerMock } from "./mocks/RandomizerMock.sol";
import { Test, console } from "forge-std/Test.sol";

import {
    ClaimsFacet,
    DiamondDeployer,
    JackpotFacet,
    MintFacet,
    MinterConfigsFacet
} from "script/libraries/DiamondDeployer.sol";
import { NFT } from "src/NFT.sol";

contract NFTMinterTest is Test {
    uint256 private constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;
    uint256 private constant TOKENS_IN_BATCH = 1000;
    uint256 private constant PRICE = 0.009e18;
    uint256 private constant CLAIM_LIMIT = 100;
    uint8 private constant SHARES_TREASURY = 30;
    uint8 private constant SHARES_GAME = 50;
    uint8 private constant WINNER_RATIO_GOLD = 50;
    uint8 private constant WINNER_RATIO_SILVER = 30;
    uint8 private constant WINNER_RATIO_BRONZE = 20;

    address private owner = makeAddr("owner");
    address private treasury = makeAddr("treasury");
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    GameMock private game;
    RandomizerMock private randomizer;
    NFT private nft;
    address private minter;

    event PauseMinting();
    event ResumeMinting();
    event Mint(uint256 price, uint256 amount, uint256 bonus, bool freeMint, address indexed to);
    event WinnerDrawn(uint256 indexed batchId, uint256 rank, address indexed winner);
    event TransferETH(address indexed to, uint256 amount);

    error InvalidShares();
    error InvalidRatios();
    error InsufficientValue();
    error InsufficientBogo();
    error BogoNotAvailable();

    function setUp() public {
        changePrank(owner, owner);

        randomizer = new RandomizerMock();

        uint8[] memory winnerRatios = new uint8[](3);
        winnerRatios[0] = WINNER_RATIO_GOLD;
        winnerRatios[1] = WINNER_RATIO_SILVER;
        winnerRatios[2] = WINNER_RATIO_BRONZE;
        nft = new NFT(false, address(randomizer), MIN_RANDOMIZER_GAS_LIMIT, address(0), "NFT", "NFT", owner);
        game = new GameMock();
        minter = DiamondDeployer.deployNFTMinter(address(nft), treasury, address(game), owner);

        vm.deal(alice, 10_000e18);
        vm.deal(bob, 10_000e18);
        vm.deal(charlie, 10_000e18);

        nft.updateMinter(address(minter));

        changePrank(alice, alice);
    }

    function test_mint_revertInsufficientValue() public {
        vm.expectRevert(InsufficientValue.selector);
        MintFacet(minter).mint{ value: PRICE - 1 }(1);
    }

    function test_mint_revertInsufficientBogo() public {
        changePrank(alice, alice);

        vm.expectRevert(InsufficientBogo.selector);
        MintFacet(minter).mintBogo{ value: PRICE }();
    }

    function test_mint() public {
        _mint(0, 0, 1, 0, PRICE, alice);
        _mint(1, 1, 3, 2, PRICE * 3, alice);
        _mint(2, 6, 5, 4, PRICE * 5, alice);
        _mint(3, 15, 10, 10, PRICE * 10, alice);

        _randomizerCallback(0, 0, 1, alice);
        _randomizerCallback(1, 1, 5, alice);
        _randomizerCallback(2, 6, 9, alice);
        _randomizerCallback(3, 15, 20, alice);

        vm.warp(vm.getBlockTimestamp() + 2 weeks);
        _mint(4, 35, 1, 0, PRICE, alice);
        _mint(5, 36, 3, 1, PRICE * 3, alice);
        _mint(6, 40, 5, 2, PRICE * 5, alice);
        _mint(7, 47, 10, 5, PRICE * 10, alice);

        _randomizerCallback(4, 35, 1, alice);
        _randomizerCallback(5, 36, 4, alice);
        _randomizerCallback(6, 40, 7, alice);
        _randomizerCallback(7, 47, 15, alice);
    }

    function test_mintBogo() public {
        game.increaseBogoOf(minter, alice);

        changePrank(alice, alice);

        MintFacet(minter).mintBogo{ value: PRICE }();

        (uint256 _tokenId, uint256 _amount, address _to, address _minter) = nft.pendingRandomizerRequests(0);
        assertEq(_tokenId, 0);
        assertEq(_amount, 2);
        assertEq(_to, alice);
        assertEq(_minter, address(minter));

        _randomizerCallback(0, 0, 2, alice);
    }

    function test_mint_100() public {
        vm.warp(vm.getBlockTimestamp() + 2 weeks);
        _mint(0, 0, 95, 5, PRICE * 95, alice);
        _randomizerCallback(0, 0, 100, alice);
    }

    function _mint(uint256 randomizerId, uint256 tokenId, uint256 amount, uint256 bonus, uint256 price, address from)
        internal
    {
        changePrank(from, from);

        vm.expectEmit();
        emit TransferETH(treasury, price * SHARES_TREASURY / 100);
        vm.expectEmit();
        emit TransferETH(address(game), price * SHARES_GAME / 100);
        vm.expectEmit();
        emit Mint(price, amount, bonus, false, from);
        MintFacet(minter).mint{ value: price }(amount);

        (uint256 _tokenId, uint256 _amount, address _to, address _minter) = nft.pendingRandomizerRequests(randomizerId);
        assertEq(_tokenId, tokenId);
        assertEq(_amount, amount + bonus);
        assertEq(_to, from);
        assertEq(_minter, address(minter));
    }

    function _randomizerCallback(uint256 randomizerId, uint256 tokenId, uint256 amount, address from) internal {
        uint256 balance = nft.balanceOf(from);
        randomizer.processPendingRequest(randomizerId, bytes32(0));
        assertEq(nft.balanceOf(from) - balance, amount);
        for (uint256 i; i < amount; ++i) {
            assertEq(nft.ownerOf(tokenId + i), from);
        }
    }

    function test_onMint() public {
        vm.warp(vm.getBlockTimestamp() + 2 weeks + 4);

        _mint(0, 0, 95, 5, PRICE * 95, alice);
        _mint(1, 100, 95, 5, PRICE * 95, alice);
        _mint(2, 200, 95, 5, PRICE * 95, alice);
        _mint(3, 300, 95, 5, PRICE * 95, alice);
        _mint(4, 400, 95, 5, PRICE * 95, alice);
        _mint(5, 500, 95, 5, PRICE * 95, bob);
        _mint(6, 600, 95, 5, PRICE * 95, bob);
        _mint(7, 700, 95, 5, PRICE * 95, bob);
        _mint(8, 800, 95, 5, PRICE * 95, charlie);
        _mint(9, 900, 95, 5, PRICE * 95, charlie);

        _randomizerCallback(0, 0, 100, alice);
        _randomizerCallback(1, 100, 100, alice);
        _randomizerCallback(2, 200, 100, alice);
        _randomizerCallback(3, 300, 100, alice);
        _randomizerCallback(4, 400, 100, alice);
        _randomizerCallback(5, 500, 100, bob);
        _randomizerCallback(6, 600, 100, bob);
        _randomizerCallback(7, 700, 100, bob);
        _randomizerCallback(8, 800, 100, charlie);
        _randomizerCallback(9, 900, 100, charlie);

        uint256 jackpot = 950 * PRICE * (100 - SHARES_TREASURY - SHARES_GAME) / 100;
        assertEq(JackpotFacet(minter).jackpot(), jackpot);
        assertEq(JackpotFacet(minter).entrantsLength(), 950);

        changePrank(alice, alice);

        MintFacet(minter).mint{ value: PRICE }(1);

        jackpot = JackpotFacet(minter).jackpot();
        vm.expectEmit();
        emit TransferETH(charlie, jackpot * WINNER_RATIO_GOLD / 100);
        vm.expectEmit();
        emit WinnerDrawn(1, 0, charlie);
        vm.expectEmit();
        emit TransferETH(alice, jackpot * WINNER_RATIO_SILVER / 100);
        vm.expectEmit();
        emit WinnerDrawn(1, 1, alice);
        vm.expectEmit();
        emit TransferETH(bob, jackpot * WINNER_RATIO_BRONZE / 100);
        vm.expectEmit();
        emit WinnerDrawn(1, 2, bob);
        randomizer.processPendingRequest(10, bytes32(0));

        assertEq(JackpotFacet(minter).batchId(), 1);
        assertEq(JackpotFacet(minter).entrantsOffset(), 951);
        assertEq(JackpotFacet(minter).entrantsLength(), 951);
    }
}
