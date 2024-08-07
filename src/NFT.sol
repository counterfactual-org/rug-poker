// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Owned } from "solmate/auth/Owned.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";

import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { IRandomizer } from "src/interfaces/IRandomizer.sol";
import { IRandomizerCallback } from "src/interfaces/IRandomizerCallback.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";

contract NFT is ERC721, Owned, IRandomizerCallback, INFT {
    struct RandomizerRequest {
        uint256 tokenId;
        uint256 amount;
        address to;
        address minter;
    }

    uint256 public constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;
    uint256 public constant MINTING_LIMIT = 100;

    bool public immutable _staging;
    address public immutable randomizer;
    uint256 public randomizerGasLimit;
    address public tokenURIRenderer;

    address public minter;

    mapping(uint256 randomizerId => RandomizerRequest) public pendingRandomizerRequests;

    uint256 public nextTokenId;

    mapping(uint256 id => bytes32) public dataOf;

    event UpdateRandomizerGasLimit(uint256 gasLimit);
    event UpdateTokenURIRenderer(address indexed tokenURIRenderer);
    event UpdateMinter(address indexed account);
    event Draw(uint256 indexed tokenId, uint256 amount, address indexed to, uint256 indexed randomizerId);
    event Mint(uint256 indexed tokenId, uint256 amount, address indexed to, address indexed minter);

    error GasLimitTooLow();
    error NotMinted();
    error Forbidden();
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientFee();
    error InvalidRandomizerId();

    modifier onlyMinter() {
        if (msg.sender != minter) revert Forbidden();
        _;
    }

    constructor(
        bool staging,
        address _randomizer,
        uint256 _randomizerGasLimit,
        address _tokenURIRenderer,
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC721(_name, _symbol) Owned(_owner) {
        _staging = staging;
        randomizer = _randomizer;
        randomizerGasLimit = _randomizerGasLimit;
        tokenURIRenderer = _tokenURIRenderer;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert NotMinted();
        return string(ITokenURIRenderer(tokenURIRenderer).render(tokenId));
    }

    function estimateRandomizerFee() public view returns (uint256) {
        return IRandomizer(randomizer).estimateFee(randomizerGasLimit);
    }

    function transferFrom(address from, address to, uint256 id) public override {
        if (from != address(this) && to != address(this)) revert Forbidden();

        super.transferFrom(from, to, id);
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) external onlyOwner {
        if (_randomizerGasLimit < MIN_RANDOMIZER_GAS_LIMIT) revert GasLimitTooLow();

        randomizerGasLimit = _randomizerGasLimit;

        emit UpdateRandomizerGasLimit(_randomizerGasLimit);
    }

    function updateTokenURIRenderer(address _tokenURIRenderer) external onlyOwner {
        if (_tokenURIRenderer == address(0)) revert InvalidAddress();

        tokenURIRenderer = _tokenURIRenderer;

        emit UpdateTokenURIRenderer(_tokenURIRenderer);
    }

    function updateMinter(address account) external onlyOwner {
        if (account == address(0)) revert InvalidAddress();

        minter = account;

        emit UpdateMinter(account);
    }

    function burn(uint256 id) external {
        if (msg.sender != ownerOf(id)) revert Forbidden();

        _burn(id);
    }

    function draw(uint256 amount, address to) external payable onlyMinter {
        if (amount == 0 || amount > MINTING_LIMIT) revert InvalidAmount();
        if (to == address(0)) revert InvalidAddress();

        uint256 fee = estimateRandomizerFee();
        if (address(this).balance < fee) revert InsufficientFee();

        address _randomizer = randomizer;
        IRandomizer(_randomizer).clientDeposit{ value: fee }(address(this));

        uint256 tokenId = nextTokenId;
        if (_staging) {
            // use psuedo-random value in staging env
            bytes32 value = keccak256(abi.encodePacked(tokenId, block.number, block.timestamp));
            _randomizerCallback(RandomizerRequest(tokenId, amount, to, msg.sender), value);
            emit Draw(tokenId, amount, to, 0);
        } else {
            uint256 randomizerId = IRandomizer(_randomizer).request(randomizerGasLimit);
            pendingRandomizerRequests[randomizerId] = RandomizerRequest(tokenId, amount, to, msg.sender);

            emit Draw(tokenId, amount, to, randomizerId);
        }

        nextTokenId = tokenId + amount;
    }

    function randomizerCallback(uint256 randomizerId, bytes32 value) external {
        if (msg.sender != randomizer) revert Forbidden();

        RandomizerRequest memory request = pendingRandomizerRequests[randomizerId];
        if (request.to == address(0)) revert InvalidRandomizerId();
        delete pendingRandomizerRequests[randomizerId];

        _randomizerCallback(request, value);
    }

    function _randomizerCallback(RandomizerRequest memory request, bytes32 value) internal {
        for (uint256 i; i < request.amount; ++i) {
            uint256 tokenId = request.tokenId + i;
            _mint(request.to, tokenId);

            bytes32 data = keccak256(abi.encodePacked(value, block.number, block.timestamp, tokenId));
            dataOf[request.tokenId] = data;
        }

        emit Mint(request.tokenId, request.amount, request.to, request.minter);

        INFTMinter(request.minter).onMint(request.tokenId, request.amount, request.to);
    }
}
