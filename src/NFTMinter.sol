// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Owned } from "solmate/auth/Owned.sol";
import { MerkleProofLib } from "solmate/utils/MerkleProofLib.sol";

import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";
import { TransferLib } from "src/libraries/TransferLib.sol";

contract NFTMinter is Owned, INFTMinter {
    uint8 private constant SHARES_TREASURY = 0;
    uint8 private constant SHARES_GAME = 1;

    address public immutable nft;
    uint256 public immutable tokensInBatch;
    address public treasury;
    address public game;
    uint256 public price;
    uint256 public initialDiscountUntil;
    uint8[2] public shares;
    uint8[] public winnerRatios;
    uint256 public mintingUnavailableFrom;
    uint256 public claimLimit;

    mapping(bytes32 merkleRoot => bool) public isMerkleRoot;
    mapping(bytes32 merkleRoot => mapping(address account => bool)) public hasClaimed;
    mapping(bytes32 merkleRoot => uint256) public totalClaimed;

    mapping(address account => uint256) public freeMintingOf;

    address[] public entrants;
    uint256 public entrantsOffset;
    uint256 public batchId;

    event UpdateTreasury(address indexed treasury);
    event UpdateGame(address indexed game);
    event UpdatePrice(uint256 price);
    event UpdateInitialDiscountUntil(uint256 initialDiscountUntil);
    event UpdateShares(uint8[2] shares);
    event UpdateWinnerRatios(uint8[] winnerRatios);
    event UpdateMintingUnavailableFrom(uint256 mintingUnavailableFrom);
    event UpdateClaimLimit(uint256 claimLimit);
    event UpdateMerkleRoot(bytes32 indexed merkleRoot, bool isMerkleRoot);
    event Claim(bytes32 indexed merkleRoot, address indexed account, uint256 amount);
    event IncreaseFreeMintingOf(address indexed account, uint256 count);
    event Mint(uint256 price, uint256 amount, address indexed to, bool freeMint);
    event WinnerDrawn(uint256 indexed batchId, uint256 rank, address indexed winner);

    error Forbidden();
    error InvalidShares();
    error InvalidRatios();
    error InsufficientValue();
    error MintingNotAvailable();
    error InsufficientFreeMinting();
    error FreeMintingNotAvailable();
    error ClaimUnavailable();
    error InvalidMerkleRoot();
    error InvalidMerkleProof();
    error AlreadyClaimed();

    constructor(
        address _nft,
        uint256 _tokensInBatch,
        address _treasury,
        address _game,
        uint256 _price,
        uint8[2] memory _shares,
        uint8[] memory _winnerRatios,
        uint256 _mintingUnavailableFrom,
        uint256 _initialDiscountUntil,
        uint256 _claimLimit,
        address _owner
    ) Owned(_owner) {
        nft = _nft;
        tokensInBatch = _tokensInBatch;
        treasury = _treasury;
        game = _game;
        price = _price;
        shares = _shares;
        winnerRatios = _winnerRatios;
        mintingUnavailableFrom = _mintingUnavailableFrom;
        initialDiscountUntil = _initialDiscountUntil;
        claimLimit = _claimLimit;
    }

    receive() external payable { }

    function entrantsLength() external view returns (uint256) {
        return entrants.length;
    }

    function jackpot() public view returns (uint256) {
        return address(this).balance;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;

        emit UpdateTreasury(_treasury);
    }

    function updateGame(address _game) external onlyOwner {
        game = _game;

        emit UpdateGame(_game);
    }

    function updatePrice(uint256 _price) external onlyOwner {
        price = _price;

        emit UpdatePrice(_price);
    }

    function updateInitialDiscountUntil(uint256 _initialDiscountUntil) external onlyOwner {
        initialDiscountUntil = _initialDiscountUntil;

        emit UpdateInitialDiscountUntil(_initialDiscountUntil);
    }

    function updateShares(uint8[2] memory _shares) external onlyOwner {
        if (_shares[SHARES_TREASURY] < 30) revert InvalidShares();
        if (_shares[SHARES_TREASURY] + _shares[SHARES_GAME] > 100) revert InvalidShares();

        shares = _shares;

        emit UpdateShares(_shares);
    }

    function updateWinnerRatios(uint8[] memory _winnerRatios) external onlyOwner {
        uint256 sum;
        for (uint256 i; i < _winnerRatios.length; ++i) {
            sum += _winnerRatios[i];
        }
        if (sum != 100) revert InvalidRatios();

        winnerRatios = _winnerRatios;

        emit UpdateWinnerRatios(_winnerRatios);
    }

    function updateMintingUnavailableFrom(uint256 _mintingUnavailableFrom) external onlyOwner {
        mintingUnavailableFrom = _mintingUnavailableFrom;

        emit UpdateMintingUnavailableFrom(_mintingUnavailableFrom);
    }

    function updateClaimLimit(uint256 _claimLimit) external onlyOwner {
        claimLimit = _claimLimit;

        emit UpdateClaimLimit(_claimLimit);
    }

    function updateMerkleRoot(bytes32 merkleRoot, bool _isMerkleRoot) external onlyOwner {
        isMerkleRoot[merkleRoot] = _isMerkleRoot;

        emit UpdateMerkleRoot(merkleRoot, _isMerkleRoot);
    }

    function increaseFreeMintingOf(address account) external {
        if (msg.sender != game) revert Forbidden();

        uint256 freeMinting = freeMintingOf[account];
        freeMintingOf[account] = freeMinting + 1;

        emit IncreaseFreeMintingOf(account, freeMinting + 1);
    }

    function claim(bytes32 merkleRoot, bytes32[] calldata proof, uint256 amount) external payable {
        uint256 _totalClaimed = totalClaimed[merkleRoot] + amount;
        if (_totalClaimed < claimLimit) revert ClaimUnavailable();
        if (!isMerkleRoot[merkleRoot]) revert InvalidMerkleRoot();
        if (hasClaimed[merkleRoot][msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        bool isValidProof = MerkleProofLib.verify(proof, merkleRoot, leaf);
        if (!isValidProof) revert InvalidMerkleProof();

        hasClaimed[merkleRoot][msg.sender] = true;
        totalClaimed[merkleRoot] = _totalClaimed;

        INFT(nft).draw{ value: msg.value }(amount, msg.sender);

        emit Claim(merkleRoot, msg.sender, amount);
    }

    function mint(uint256 amount) external payable {
        mint(amount, false);
    }

    function mint(uint256 amount, bool freeMint) public payable {
        if (freeMint) {
            uint256 freeMinting = freeMintingOf[msg.sender];
            if (freeMinting == 0) revert InsufficientFreeMinting();
            if (amount != 1) revert FreeMintingNotAvailable();
            freeMintingOf[msg.sender] = freeMinting - 1;
        }

        uint256 tokenId = INFT(nft).nextTokenId() + amount + (freeMint ? 1 : 0);
        if (tokenId > mintingUnavailableFrom) revert MintingNotAvailable();

        bool initialDiscount = block.timestamp < initialDiscountUntil;
        uint256 discounted =
            (amount >= 10) ? (initialDiscount ? 70 : 80) : (amount >= 5) ? (initialDiscount ? 80 : 88) : 100;
        uint256 totalPrice = amount * price * discounted / 100;
        if (msg.value < totalPrice) revert InsufficientValue();

        TransferLib.transferETH(treasury, totalPrice * shares[SHARES_TREASURY] / 100, address(0));
        TransferLib.transferETH(game, totalPrice * shares[SHARES_GAME] / 100, address(0));

        for (uint256 i; i < amount; ++i) {
            entrants.push(msg.sender);
        }

        INFT(nft).draw{ value: msg.value - totalPrice }(amount + (freeMint ? 1 : 0), msg.sender);

        emit Mint(totalPrice, amount, msg.sender, freeMint);
    }

    function onMint(uint256 tokenId, uint256 amount, address) external {
        uint256 _batchId = (tokenId + amount - 1) / tokensInBatch;
        if (_batchId <= batchId) return;
        batchId = _batchId;

        uint256 prize = jackpot();
        if (prize == 0) return;

        bytes32 data = INFT(nft).dataOf(tokenId);
        uint256 offset = entrantsOffset;
        uint256 size = entrants.length - offset;
        for (uint256 i; i < winnerRatios.length; ++i) {
            data = keccak256(abi.encodePacked(data, i));
            address winner = entrants[offset + uint256(data) % size];
            TransferLib.transferETH(winner, prize * winnerRatios[i] / 100, address(this));

            emit WinnerDrawn(_batchId, i, winner);
        }

        entrantsOffset = entrants.length;
    }
}
