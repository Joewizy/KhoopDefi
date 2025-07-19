// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC721A.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract SolyTicket is ERC2771Context, ERC721A, IERC2981, Ownable {
    string public baseURI;
    uint256 public _totalNFTs;
    string public _name;
    string public _tag;

    // Minimal Forwarder Address
    address public trustedForwarderAddress;

    uint256 public constant ROYALTY_PERCENTAGE = 1000; // 10% in basis points

    // Secondary sales control toggle
    bool public secondarySalesEnabled;

    // Marketplace listing structure
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    uint256 public nextListingId;
    mapping(uint256 => Listing) public listings;

    // Events
    event NFTListed(uint256 indexed listingId, address indexed seller, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer);
    event ListingCanceled(uint256 indexed listingId);

    constructor(
        address owner,
        uint256 totalNFTs,
        string memory name,
        string memory tag,
        string memory arweaveBaseURI,
        address _trustedForwarderAddress
    ) ERC721A(name, tag) ERC2771Context(_trustedForwarderAddress) Ownable() {
        _totalNFTs = totalNFTs;
        _name = name;
        _tag = tag;
        baseURI = arweaveBaseURI;
        trustedForwarderAddress = _trustedForwarderAddress;
        _safeMint(address(this), totalNFTs); // Mint all NFTs to contract custody initially
        secondarySalesEnabled = false;
        _transferOwnership(owner); // transfer ownership to the owner
    }

    // --- NFT Functions ---

    /// @notice Burn multiple tokens, only callable by owner
    function burn(uint256[] calldata tokenIds) external onlyOwner {
        _batchBurn(address(0), tokenIds);
        // ERC721A already refunds gas on standard burn, no extra function needed
    }

    /// @notice Gift NFTs from contract custody to a receiver, only owner can call
    function giftNFTs(uint256[] calldata NFTIds, address receiver) external onlyOwner {
        _batchTransferFrom(address(this), receiver, NFTIds);
    }

    /// @dev Override ERC721A start token ID to 1 instead of 0
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Returns token URI based on baseURI + tokenId + ".json"
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Token doesn't exist");
        return string(abi.encodePacked(baseURI, _toString(tokenId), ".json"));
    }

    /// @dev Base URI override
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // --- Marketplace Functions ---

    /// @notice List NFT for resale
    function listNFT(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == _msgSender(), "Not the owner");
        require(secondarySalesEnabled, "Secondary sales are disabled");
        listings[nextListingId] = Listing({tokenId: tokenId, seller: _msgSender(), price: price, active: true});
        emit NFTListed(nextListingId, _msgSender(), tokenId, price);
        nextListingId++;
    }

    /// @notice Fulfill sale after off-chain payment, only owner can call
    function fulfillSale(uint256 listingId, address buyer) external onlyOwner {
        Listing memory l = listings[listingId];
        require(l.active, "Listing not active");
        require(ownerOf(l.tokenId) == l.seller, "Seller no longer owns NFT");
        transferFrom(l.seller, buyer, l.tokenId);
        listings[listingId].active = false;
        emit NFTSold(listingId, buyer);
    }

    /// @notice Cancel resale listing, only seller can call
    function cancelListing(uint256 listingId) external {
        Listing memory l = listings[listingId];
        require(l.active, "Listing inactive");
        require(_msgSender() == l.seller, "Only seller can cancel");
        listings[listingId].active = false;
        emit ListingCanceled(listingId);
    }

    /// @notice Get details of a listing
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    // --- Admin Controls ---

    /// @notice Enable or disable secondary sales
    function toggleSecondarySales(bool enabled) external onlyOwner {
        secondarySalesEnabled = enabled;
    }

    /// @notice Batch update token URIs if needed (optional)
    function batchSetTokenURIs(uint256[] calldata tokenIds, string[] calldata cids) external view onlyOwner {
        require(tokenIds.length == cids.length, "Array length mismatch");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == address(this), "Can only update unassigned tokens");
            // Extend here if you want to store per-token CID mapping
            // e.g. mapCidWithNftId[tokenIds[i]] = cids[i];
        }
    }

    // --- Transfer Restrictions ---

    /// @dev Restrict transfers to minting, gifting by contract, admin transfers, or if secondary sales enabled
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        override
    {
        require(
            from == address(0) // Minting
                || from == address(this) // Initial gifting from contract custody
                || _msgSender() == owner() // Admin transfers (including fulfillSale)
                || secondarySalesEnabled, // Allow transfers if secondary sales enabled
            "Transfers restricted"
        );
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    // --- Royalty Info (EIP-2981) ---

    /// @notice Returns royalty info for marketplace
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");
        uint256 amount = (salePrice * ROYALTY_PERCENTAGE) / 10000;
        return (owner(), amount);
    }

    /// @notice Supports interfaces including IERC2981
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice ERC721 Receiver implementation to allow safe transfers to contract
    function onERC721Received(address, /*operator*/ address, /*from*/ uint256, /*tokenId*/ bytes calldata /*data*/ )
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    /// @notice
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}
