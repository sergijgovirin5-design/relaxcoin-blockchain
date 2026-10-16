// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IR2RPurchaseToken {
    function processPurchaseFor(address buyer, address seller, uint256 amount) external returns (bool);
}

/// @title Relax NFT Platform
/// @notice Users can mint NFTs, while platform funds and NFT metadata stay protected.
contract RelaxNFTPlatform is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum MediaType {
        Image,
        Video
    }

    IERC20 public immutable paymentToken;
    address public immutable treasury;
    uint256 public immutable mintFee;
    bool public paused;
    address public timelock;
    uint256 public royaltyFeeBp;
    string public baseURI;

    uint256 public constant MIN_EDITION_SIZE = 2;
    uint256 public constant MAX_EDITION_SIZE = 400;
    uint256 public constant MAX_MEDIA_PER_COLLECTION = 2000;
    uint256 public constant MAX_COLLECTIONS_PER_CREATOR = 100;
    uint256 public constant MAX_TOTAL_SUPPLY = 1000000;
    uint256 public constant MAX_NFT_NAME_LENGTH = 79;

    uint256 public totalMinted;
    uint256 public totalCollections;
    mapping(address => uint256) public creatorCollections;
    mapping(uint256 => address) public collectionCreator;
    mapping(uint256 => uint256) public collectionImageCount;
    mapping(uint256 => uint256) public collectionMintedCopies;
    mapping(uint256 => address) public creatorOf;
    mapping(uint256 => uint256) public collectionOf;
    mapping(uint256 => uint256) public imageOf;
    mapping(uint256 => uint256) public editionSizeOf;
    mapping(uint256 => MediaType) public mediaTypeOf;
    mapping(uint256 => string) public nftNameOf;
    mapping(address => bool) public blockedCreator;
    mapping(uint256 => uint256) public nftPrice;
    mapping(uint256 => bool) public nftListed;
    address public purchaseProcessor;

    event CollectionCreated(uint256 indexed collectionId, address indexed creator);
    event EditionMinted(
        uint256 indexed collectionId,
        uint256 indexed imageId,
        address indexed creator,
        uint256 firstTokenId,
        uint256 editionSize,
        MediaType mediaType,
        string nftName,
        string tokenUri
    );
    event CreatorBlocked(address indexed creator, bool blocked);
    event DigitalProductPurchased(address indexed buyer, address indexed seller, uint256 amount, bytes32 indexed productId);
    event PurchaseProcessorUpdated(address indexed processor);
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 amount);

    constructor(IERC20 _paymentToken, address _treasury, uint256 _mintFee)
        ERC721("Relax NFT", "RNFT")
        Ownable(msg.sender)
    {
        require(address(_paymentToken) != address(0), "RelaxNFT: payment token zero");
        require(_treasury != address(0), "RelaxNFT: treasury zero");
        require(_mintFee > 0, "RelaxNFT: fee zero");

        paymentToken = _paymentToken;
        treasury = _treasury;
        mintFee = _mintFee;
    }

    modifier whenNotPaused() {
        require(!paused, "RelaxNFT: paused");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == timelock, "RelaxNFT: not admin");
        _;
    }

    function setTimelock(address _timelock) external onlyOwner {
        require(_timelock != address(0), "RelaxNFT: timelock zero");
        timelock = _timelock;
    }

    function pause() external onlyAdmin {
        paused = true;
    }

    function unpause() external onlyAdmin {
        paused = false;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(0) && to != address(0), "RelaxNFT: invalid address");
        IERC20(token).transfer(to, amount);
    }

    function setRoyaltyFee(uint256 feeBp) external onlyAdmin {
        require(feeBp <= 10000, "RelaxNFT: royalty too high");
        royaltyFeeBp = feeBp;
    }

    function setBaseURI(string memory uri) external onlyAdmin {
        baseURI = uri;
    }

    function createCollection() external whenNotPaused returns (uint256 collectionId) {
        require(!blockedCreator[msg.sender], "RelaxNFT: creator blocked");
        require(creatorCollections[msg.sender] < MAX_COLLECTIONS_PER_CREATOR, "RelaxNFT: collection limit");

        collectionId = ++totalCollections;
        creatorCollections[msg.sender] += 1;
        collectionCreator[collectionId] = msg.sender;

        emit CollectionCreated(collectionId, msg.sender);
    }

    function purchaseDigitalProduct(address seller, uint256 amount, bytes32 productId)
        external
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        require(seller != address(0), "RelaxNFT: seller zero");
        require(amount > 0, "RelaxNFT: amount zero");
        require(purchaseProcessor != address(0), "RelaxNFT: processor not set");
        require(IR2RPurchaseToken(purchaseProcessor).processPurchaseFor(msg.sender, seller, amount), "RelaxNFT: purchase failed");
        emit DigitalProductPurchased(msg.sender, seller, amount, productId);
        return true;
    }

    function setPurchaseProcessor(address processor) external onlyOwner {
        require(processor != address(0), "RelaxNFT: processor zero");
        purchaseProcessor = processor;
        emit PurchaseProcessorUpdated(processor);
    }

    function listNFT(uint256 tokenId, uint256 price) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "RelaxNFT: not NFT owner");
        require(price > 0, "RelaxNFT: price zero");
        nftPrice[tokenId] = price;
        nftListed[tokenId] = true;
        emit NFTListed(tokenId, msg.sender, price);
    }

    function purchaseNFT(uint256 tokenId) external nonReentrant whenNotPaused {
        require(nftListed[tokenId], "RelaxNFT: NFT not listed");
        require(purchaseProcessor != address(0), "RelaxNFT: processor not set");

        address seller = ownerOf(tokenId);
        uint256 price = nftPrice[tokenId];
        require(IR2RPurchaseToken(purchaseProcessor).processPurchaseFor(msg.sender, seller, price), "RelaxNFT: purchase failed");
        nftListed[tokenId] = false;
        _transfer(seller, msg.sender, tokenId);
        emit NFTPurchased(tokenId, msg.sender, price);
    }

    function mintEdition(
        uint256 collectionId,
        string calldata tokenUri,
        uint256 editionSize,
        MediaType mediaType,
        string calldata nftName
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 firstTokenId)
    {
        require(!blockedCreator[msg.sender], "RelaxNFT: creator blocked");
        require(collectionCreator[collectionId] == msg.sender, "RelaxNFT: not collection creator");
        require(bytes(tokenUri).length > 0, "RelaxNFT: URI empty");
        require(_validName(nftName), "RelaxNFT: invalid name");
        require(editionSize >= MIN_EDITION_SIZE && editionSize <= MAX_EDITION_SIZE, "RelaxNFT: invalid edition size");
        require(collectionImageCount[collectionId] < MAX_MEDIA_PER_COLLECTION, "RelaxNFT: media limit");
        require(totalMinted + editionSize <= MAX_TOTAL_SUPPLY, "RelaxNFT: supply limit");

        paymentToken.safeTransferFrom(msg.sender, treasury, mintFee);

        uint256 imageId = ++collectionImageCount[collectionId];
        collectionMintedCopies[collectionId] += editionSize;
        firstTokenId = totalMinted + 1;

        for (uint256 copy = 0; copy < editionSize; copy++) {
            uint256 tokenId = ++totalMinted;
            creatorOf[tokenId] = msg.sender;
            collectionOf[tokenId] = collectionId;
            imageOf[tokenId] = imageId;
            editionSizeOf[tokenId] = editionSize;
            mediaTypeOf[tokenId] = mediaType;
            nftNameOf[tokenId] = nftName;
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, tokenUri);
        }

        emit EditionMinted(collectionId, imageId, msg.sender, firstTokenId, editionSize, mediaType, nftName, tokenUri);
    }

    function _validName(string calldata nftName) internal pure returns (bool) {
        bytes calldata nameBytes = bytes(nftName);
        if (nameBytes.length == 0 || nameBytes.length > MAX_NFT_NAME_LENGTH) {
            return false;
        }

        for (uint256 index = 0; index < nameBytes.length; index++) {
            bytes1 character = nameBytes[index];
            bool isDigit = character >= 0x30 && character <= 0x39;
            bool isUppercase = character >= 0x41 && character <= 0x5A;
            bool isLowercase = character >= 0x61 && character <= 0x7A;
            if (!isDigit && !isUppercase && !isLowercase) {
                return false;
            }
        }

        return true;
    }

    function setCreatorBlocked(address creator, bool blocked) external onlyOwner {
        require(creator != address(0), "RelaxNFT: creator zero");
        blockedCreator[creator] = blocked;
        emit CreatorBlocked(creator, blocked);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}