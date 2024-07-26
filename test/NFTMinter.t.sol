// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GameMock } from "./mocks/GameMock.sol";
import { RandomizerMock } from "./mocks/RandomizerMock.sol";
import { Test, console } from "forge-std/Test.sol";

import { NFT } from "src/NFT.sol";
import { NFTMinter } from "src/NFTMinter.sol";

contract NFTMinterTest is Test {
    uint256 private constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;
    uint8 private constant SHARES_TREASURY = 30;
    uint8 private constant SHARES_GAME = 50;
    uint8 private constant WINNER_RATIO_GOLD = 50;
    uint8 private constant WINNER_RATIO_SILVER = 30;
    uint8 private constant WINNER_RATIO_BRONZE = 20;
    uint256 private constant TOKENS_IN_BATCH = 1000;
    uint256 private constant PRICE = 0.009e18;
    uint256 private constant MINTING_UP_TO = 2000;
    uint256 private constant CLAIM_LIMIT = 500;

    address private owner = makeAddr("owner");
    address private treasury = makeAddr("treasury");
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    GameMock private game;
    RandomizerMock private randomizer;
    NFT private nft;
    NFTMinter private minter;

    event PauseMinting();
    event ResumeMinting();
    event Mint(uint256 price, uint256 amount, address indexed to, bool freeMint);
    event WinnerDrawn(uint256 indexed batchId, uint256 rank, address indexed winner);
    event TransferETH(address indexed to, uint256 amount);

    error InvalidShares();
    error InvalidRatios();
    error InsufficientValue();
    error MintingNotAvailable();
    error InsufficientFreeMinting();
    error FreeMintingNotAvailable();

    function setUp() public {
        randomizer = new RandomizerMock();

        uint8[] memory winnerRatios = new uint8[](3);
        winnerRatios[0] = WINNER_RATIO_GOLD;
        winnerRatios[1] = WINNER_RATIO_SILVER;
        winnerRatios[2] = WINNER_RATIO_BRONZE;
        nft = new NFT("NFT", "NFT", address(randomizer), MIN_RANDOMIZER_GAS_LIMIT, address(0), owner);
        minter = new NFTMinter(
            address(nft),
            TOKENS_IN_BATCH,
            treasury,
            address(0),
            PRICE,
            [SHARES_TREASURY, SHARES_GAME],
            winnerRatios,
            MINTING_UP_TO,
            vm.getBlockTimestamp() + 1 weeks,
            CLAIM_LIMIT,
            owner
        );
        game = new GameMock(address(minter));

        vm.deal(alice, 10_000e18);
        vm.deal(bob, 10_000e18);
        vm.deal(charlie, 10_000e18);

        changePrank(owner, owner);
        minter.updateGame(address(game));
        nft.updateMinter(address(minter));

        changePrank(alice, alice);
    }

    function test_updateWinnerRatios_revertForbidden() public {
        uint8[] memory winnerRatios = new uint8[](3);

        vm.expectRevert("UNAUTHORIZED");
        minter.updateWinnerRatios(winnerRatios);
    }

    function test_updateWinnerRatios_revertInvalidRatios() public {
        changePrank(owner, owner);

        uint8[] memory winnerRatios = new uint8[](3);
        winnerRatios[0] = 50;
        winnerRatios[1] = 30;
        winnerRatios[2] = 9;

        vm.expectRevert(InvalidRatios.selector);
        minter.updateWinnerRatios(winnerRatios);
    }

    function test_mint_revertInsufficientValue() public {
        vm.expectRevert(InsufficientValue.selector);
        minter.mint{ value: PRICE - 1 }(1);
    }

    function test_mint_revertMintingPaused() public {
        uint256 price = PRICE * 70 / 100;
        for (uint256 i; i < 20; ++i) {
            _mint(i, i * 100, 100, 100 * price, alice);
            randomizer.processPendingRequest(i, bytes32(0));
        }
        vm.expectRevert(MintingNotAvailable.selector);
        minter.mint{ value: PRICE }(1);
    }

    function test_mint_revertInsufficientFreeMinting() public {
        changePrank(alice, alice);

        vm.expectRevert(InsufficientFreeMinting.selector);
        minter.mint{ value: PRICE }(1, true);
    }

    function test_mint_revertFreeMintingNotAvailable() public {
        game.increaseFreeMintingOf(alice);

        changePrank(alice, alice);

        vm.expectRevert(FreeMintingNotAvailable.selector);
        minter.mint{ value: PRICE }(2, true);
    }

    function test_mint() public {
        _mint(0, 0, 1, PRICE, alice);
        _mint(1, 1, 5, PRICE * 5 * 80 / 100, alice);
        _mint(2, 6, 10, PRICE * 10 * 70 / 100, alice);

        _randomizerCallback(0, 0, 1, alice);
        _randomizerCallback(1, 1, 5, alice);
        _randomizerCallback(2, 6, 10, alice);

        vm.warp(vm.getBlockTimestamp() + 1 weeks);
        _mint(3, 16, 1, PRICE, alice);
        _mint(4, 17, 5, PRICE * 5 * 88 / 100, alice);
        _mint(5, 22, 10, PRICE * 10 * 80 / 100, alice);

        _randomizerCallback(3, 16, 1, alice);
        _randomizerCallback(4, 17, 5, alice);
        _randomizerCallback(5, 22, 10, alice);
    }

    function test_mint_withFreeMinting() public {
        game.increaseFreeMintingOf(alice);

        changePrank(alice, alice);

        minter.mint{ value: PRICE }(1, true);

        (uint256 _tokenId, uint256 _amount, address _to, address _minter) = nft.pendingRandomizerRequests(0);
        assertEq(_tokenId, 0);
        assertEq(_amount, 2);
        assertEq(_to, alice);
        assertEq(_minter, address(minter));

        _randomizerCallback(0, 0, 2, alice);
    }

    function test_mint_100() public {
        _mint(0, 0, 100, PRICE * 100 * 70 / 100, alice);
        _randomizerCallback(0, 0, 100, alice);
    }

    function _mint(uint256 randomizerId, uint256 tokenId, uint256 amount, uint256 price, address from) internal {
        changePrank(from, from);

        vm.expectEmit();
        emit TransferETH(treasury, price * SHARES_TREASURY / 100);
        vm.expectEmit();
        emit TransferETH(address(game), price * SHARES_GAME / 100);
        vm.expectEmit();
        emit Mint(price, amount, from, false);
        minter.mint{ value: price }(amount);

        (uint256 _tokenId, uint256 _amount, address _to, address _minter) = nft.pendingRandomizerRequests(randomizerId);
        assertEq(_tokenId, tokenId);
        assertEq(_amount, amount);
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
        uint256 price = PRICE * 70 / 100;
        _mint(0, 0, 100, 100 * price, alice);
        _mint(1, 100, 100, 100 * price, alice);
        _mint(2, 200, 100, 100 * price, alice);
        _mint(3, 300, 100, 100 * price, alice);
        _mint(4, 400, 100, 100 * price, alice);
        _mint(5, 500, 100, 100 * price, bob);
        _mint(6, 600, 100, 100 * price, bob);
        _mint(7, 700, 100, 100 * price, bob);
        _mint(8, 800, 100, 100 * price, charlie);
        _mint(9, 900, 100, 100 * price, charlie);

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

        uint256 jackpot = 1000 * price * (100 - SHARES_TREASURY - SHARES_GAME) / 100;
        assertEq(minter.jackpot(), jackpot);
        assertEq(minter.entrantsLength(), 1000);

        changePrank(alice, alice);

        minter.mint{ value: PRICE }(1);

        jackpot = minter.jackpot();
        vm.expectEmit();
        emit TransferETH(charlie, jackpot * WINNER_RATIO_GOLD / 100);
        vm.expectEmit();
        emit WinnerDrawn(1, 0, charlie);
        vm.expectEmit();
        emit TransferETH(bob, jackpot * WINNER_RATIO_SILVER / 100);
        vm.expectEmit();
        emit WinnerDrawn(1, 1, bob);
        vm.expectEmit();
        emit TransferETH(alice, jackpot * WINNER_RATIO_BRONZE / 100);
        vm.expectEmit();
        emit WinnerDrawn(1, 2, alice);
        randomizer.processPendingRequest(10, bytes32(0));

        assertEq(minter.batchId(), 1);
        assertEq(minter.entrantsOffset(), 1001);
        assertEq(minter.entrantsLength(), 1001);
    }
}
