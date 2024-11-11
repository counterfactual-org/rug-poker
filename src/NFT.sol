// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Owned } from "solmate/auth/Owned.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";

import { INFT } from "src/interfaces/INFT.sol";
import { ITokenURIRenderer } from "src/interfaces/ITokenURIRenderer.sol";

contract NFT is ERC721, Owned, INFT {
    address public tokenURIRenderer;

    address public minter;
    mapping(address => bool) public isApp;

    uint256 public nextTokenId;

    mapping(uint256 id => bytes32) public dataOf;

    event UpdateTokenURIRenderer(address indexed tokenURIRenderer);
    event UpdateMinter(address indexed account);
    event UpdateApp(address indexed account, bool indexed isApp);

    error NotMinted();
    error Forbidden();
    error InvalidAddress();

    modifier onlyMinter() {
        if (msg.sender != minter) revert Forbidden();
        _;
    }

    constructor(address _tokenURIRenderer, string memory _name, string memory _symbol, address _owner)
        ERC721(_name, _symbol)
        Owned(_owner)
    {
        tokenURIRenderer = _tokenURIRenderer;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert NotMinted();
        return string(ITokenURIRenderer(tokenURIRenderer).render(tokenId));
    }

    function transferFrom(address from, address to, uint256 id) public override {
        if (!isApp[from] && !isApp[to]) revert Forbidden();

        super.transferFrom(from, to, id);
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

    function updateApp(address account, bool _isApp) external onlyOwner {
        if (account == address(0)) revert InvalidAddress();

        isApp[account] = _isApp;

        emit UpdateApp(account, _isApp);
    }

    function mintWithData(address to, bytes32 seed) external onlyMinter {
        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);

        dataOf[tokenId] = keccak256(abi.encodePacked(seed, block.number, block.timestamp, tokenId));

        nextTokenId = tokenId + 1;
    }

    function burn(uint256 id) external {
        if (msg.sender != ownerOf(id)) revert Forbidden();

        _burn(id);
    }
}
