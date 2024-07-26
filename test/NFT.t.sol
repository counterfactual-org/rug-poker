// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GameMock } from "./mocks/GameMock.sol";
import { NFTMinterMock } from "./mocks/NFTMinterMock.sol";
import { RandomizerMock } from "./mocks/RandomizerMock.sol";
import { SvgRendererMock } from "./mocks/SvgRendererMock.sol";
import { TokenURIRendererMock } from "./mocks/TokenURIRendererMock.sol";
import { Test, console } from "forge-std/Test.sol";
import { LibString } from "solmate/utils/LibString.sol";

import { NFT } from "src/NFT.sol";
import { IAttributesFormula } from "src/interfaces/IAttributesFormula.sol";
import { Base64 } from "src/libraries/Base64.sol";

contract NFTTest is Test {
    using LibString for uint256;
    using LibString for string;

    uint256 public constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;
    uint256 public constant MINTING_LIMIT = 100;
    uint256 public constant RANDOMIZER_FEE = 0.001e18;

    address private owner = makeAddr("owner");
    address private treasury = makeAddr("treasury");
    address private jackpot = makeAddr("jackpot");
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");

    GameMock private game;
    TokenURIRendererMock private tokenURIRenderer;
    RandomizerMock private randomizer;
    NFTMinterMock private minter;
    NFT private nft;

    event Draw(uint256 indexed tokenId, uint256 amount, address indexed to, uint256 indexed randomizerId);
    event Mint(
        uint256 indexed tokenId, uint256 amount, address indexed to, address indexed minter, uint256 randomizerId
    );

    error GasLimitTooLow();
    error NotMinted();
    error Forbidden();
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientFee();
    error InvalidRandomizerId();

    function setUp() public {
        tokenURIRenderer = new TokenURIRendererMock();
        randomizer = new RandomizerMock();
        nft = new NFT("NFT", "NFT", address(randomizer), MIN_RANDOMIZER_GAS_LIMIT, address(tokenURIRenderer), owner);
        minter = new NFTMinterMock(address(nft));
        game = new GameMock(address(minter));

        vm.deal(alice, 10_000e18);
        vm.deal(bob, 10_000e18);

        changePrank(owner, owner);
        nft.updateMinter(address(minter));

        changePrank(alice, alice);
    }

    function test_transferFrom_revertForbidden() public {
        vm.expectRevert(Forbidden.selector);
        nft.transferFrom(alice, bob, 0);
    }

    function test_updateTokenURIRenderer_revertUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        nft.updateTokenURIRenderer(address(0));
    }

    function test_updateTokenURIRenderer_revertInvalidAddress() public {
        changePrank(owner, owner);

        vm.expectRevert(InvalidAddress.selector);
        nft.updateTokenURIRenderer(address(0));
    }

    function test_updateTokenURIRenderer() public {
        changePrank(owner, owner);

        nft.updateTokenURIRenderer(bob);

        assertEq(nft.tokenURIRenderer(), bob);
    }

    function test_updateRandomizerGasLimit_revertUnauthorized() public {
        vm.expectRevert("UNAUTHORIZED");
        nft.updateRandomizerGasLimit(0);
    }

    function test_updateRandomizerGasLimit_revertGasLimitTooLow() public {
        changePrank(owner, owner);

        vm.expectRevert(GasLimitTooLow.selector);
        nft.updateRandomizerGasLimit(0);
    }

    function test_updateRandomizerGasLimit() public {
        changePrank(owner, owner);

        nft.updateRandomizerGasLimit(MIN_RANDOMIZER_GAS_LIMIT + 1);

        assertEq(nft.randomizerGasLimit(), MIN_RANDOMIZER_GAS_LIMIT + 1);
    }

    function test_draw_revertInvalidAmount() public {
        randomizer.setEstimateFee(RANDOMIZER_FEE);

        vm.expectRevert(InvalidAmount.selector);
        // calls draw() internally
        minter.mint{ value: RANDOMIZER_FEE }(0);

        vm.expectRevert(InvalidAmount.selector);
        // calls draw() internally
        minter.mint{ value: RANDOMIZER_FEE }(101);
    }

    function test_draw_revertInsufficientFee() public {
        randomizer.setEstimateFee(RANDOMIZER_FEE);

        vm.expectRevert(InsufficientFee.selector);
        // calls draw() internally
        minter.mint{ value: RANDOMIZER_FEE - 1 }(1);
    }

    function test_draw() public {
        randomizer.setEstimateFee(RANDOMIZER_FEE);

        _draw(0, 1, alice, 0);
        _draw(1, 3, bob, 1);
        _draw(2, 5, alice, 4);
        _draw(3, 10, bob, 9);
    }

    function _draw(uint256 randomizerId, uint256 amount, address from, uint256 tokenIdExpected) internal {
        changePrank(from, from);

        uint256 balance = address(randomizer).balance;

        vm.expectEmit();
        emit Draw(tokenIdExpected, amount, from, randomizerId);
        // calls draw() internally
        minter.mint{ value: RANDOMIZER_FEE }(amount);

        (uint256 _tokenId, uint256 _amount, address _requester, address _minter) =
            nft.pendingRandomizerRequests(randomizerId);
        assertEq(_tokenId, tokenIdExpected);
        assertEq(_amount, amount);
        assertEq(_requester, from);
        assertEq(_minter, address(minter));
        assertEq(address(randomizer).balance - balance, RANDOMIZER_FEE);
    }

    function test_randomizerCallback_revertForbidden() public {
        vm.expectRevert(Forbidden.selector);
        nft.randomizerCallback(0, bytes32(0));
    }

    function test_randomizerCallback_revertInvalidRandomizerId() public {
        changePrank(address(randomizer), address(randomizer));

        vm.expectRevert(InvalidRandomizerId.selector);
        nft.randomizerCallback(0, bytes32(0));
    }

    function test_randomizerCallback(bytes32 value) public {
        bytes32 value2 = keccak256(abi.encodePacked(value));

        randomizer.setEstimateFee(RANDOMIZER_FEE);

        changePrank(alice, alice);
        _draw(0, 1, alice, 0);

        changePrank(bob, bob);
        _draw(1, 2, bob, 1);

        bytes32 data = keccak256(abi.encodePacked(value, vm.getBlockNumber(), vm.getBlockTimestamp()));
        _randomizerCallback(0, data, alice, 0, 1);

        bytes32 data2 = keccak256(abi.encodePacked(value2, vm.getBlockNumber(), vm.getBlockTimestamp()));
        _randomizerCallback(1, data2, bob, 1, 2);
    }

    function _randomizerCallback(
        uint256 randomizerId,
        bytes32 data,
        address from,
        uint256 tokenIdExpected,
        uint256 amountExpected
    ) internal {
        uint256 balance = nft.balanceOf(from);

        vm.expectEmit();
        emit Mint(tokenIdExpected, amountExpected, from, address(minter), randomizerId);
        // calls randomizerCallback internally
        randomizer.processPendingRequest(randomizerId, data);

        (,, address to,) = nft.pendingRandomizerRequests(randomizerId);
        assertEq(to, address(0));

        for (uint256 i; i < amountExpected; ++i) {
            assertEq(nft.ownerOf(tokenIdExpected + i), from);
        }
        assertEq(nft.balanceOf(from) - balance, amountExpected);
    }
}
