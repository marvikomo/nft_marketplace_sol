//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFTMarket is ReentrancyGuard, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    address payable owner;

    mapping(uint256 => mapping(address => uint256)) public offers;
    mapping(uint256 => marketItems) private idToMarketItem;
    mapping(uint256 => auction) public idToAuction;
    uint256 listingPrice = 0.025 ether;
    uint256 minPrice; //minimum price for an auction

    constructor() ERC721("NFTart Tokens", "NFTART") {
        owner = payable(msg.sender);
    }

    struct marketItems {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        address creator;
        uint256 price;
        bool sold;
    }

    struct auction {
        //uint32 bidIncreasePercentage;
        uint256 auctionBidPeriod;
        uint256 auctionEnd;
        uint256 minPrice;
        uint256 buyNowPrice;
        uint256 nftHighestBid;
        address nftContractAddress;
        address nftHighestBidder;
        uint256 tokenId;
        address seller;
        bool ended;
    }

    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        address creator,
        bool sold
    );

    event AuctionCreated(
        uint256 auctionBidPeriod,
        uint256 auctionEnd,
        uint256 minPrice,
        uint256 buyNowPrice,
        uint256 nftHighestBid,
        address nftContractAddress,
        address nftHighestBidder,
        uint256 indexed tokenId,
        address seller,
        bool ended
    );

    event BidMade(uint256 indexed tokenId, address bidder, uint256 amount);

    event AcceptBid(uint256 indexed tokenId, address winner, uint256 amount);

    function createToken(string memory tokenURI, uint256 price)
        public
        payable
        returns (uint256)
    {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    //gets minimum price to start the auction
    function getMinPrice() public view returns (uint256) {
        return minPrice;
    }

    function createMarketItem(uint256 tokenId, uint256 price)
        private
        nonReentrant
    {
        // require(price > 0, "Price must be at least 1 wei");
        // require(
        //     msg.value == listingPrice,
        //     "Price must be equal to listing price"
        // );
        minPrice = price;
        idToMarketItem[tokenId] = marketItems(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            msg.sender,
            price,
            false
        );
        _transfer(msg.sender, address(this), tokenId);
        require(
            IERC721(address(this)).ownerOf(tokenId) == address(this),
            "nft transfer failed"
        );
        emit MarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            msg.sender,
            false
        );
    }

    //creates auction for the NFT
    function createAuction(
        uint256 tokenId,
        uint256 auctionBidPeriod,
        uint256 price,
        address seller
    ) public {
        idToAuction[tokenId] = auction(
            auctionBidPeriod,
            block.timestamp + auctionBidPeriod,
            price,
            0,
            0,
            address(this),
            address(0),
            tokenId,
            seller,
            false
        );

        emit AuctionCreated(
            auctionBidPeriod,
            block.timestamp + auctionBidPeriod,
            price,
            0,
            0,
            address(this),
            address(0),
            tokenId,
            seller,
            false
        );
    }

    function placeBid(uint256 tokenId, uint256 amount) public {
        require(
            block.timestamp < idToAuction[tokenId].auctionEnd,
            "auction has ended"
        );
        require(
            amount >= idToMarketItem[tokenId].price,
            "You can not bid lower down asking price"
        );
        require(
            amount >= idToAuction[tokenId].nftHighestBid,
            "There is already a higher or equal bid"
        );

        idToAuction[tokenId].nftHighestBidder = msg.sender;
        idToAuction[tokenId].nftHighestBid = amount;
        offers[tokenId][msg.sender] = amount;
        emit BidMade(tokenId, msg.sender, amount);
    }

    function accept(uint256 tokenId) public {
        //add modifier for ownership
        require(
            block.timestamp >= idToAuction[tokenId].auctionEnd,
            "auction has ended"
        );
        createMarketSale(tokenId);
        emit AcceptBid(
            tokenId,
            idToAuction[tokenId].nftHighestBidder,
            idToAuction[tokenId].nftHighestBid
        );
    }

    function createMarketSale(uint256 tokenId) public payable nonReentrant {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listingPrice);
        payable(seller).transfer(msg.value);
    }

    //fetch unsold items
    function fetchMarketItems() public view returns (marketItems[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        marketItems[] memory items = new marketItems[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                marketItems storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //return only items that a user has purchased
    function fetchNFTS() public view returns (marketItems[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        marketItems[] memory items = new marketItems[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                marketItems storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //return only items a user has listed
    function fetchItemsListed() public view returns (marketItems[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }
        marketItems[] memory items = new marketItems[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                marketItems storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idToMarketItem[tokenId].owner == msg.sender,
            "only token owner is allowed"
        );
        require(
            msg.value == listingPrice,
            "price must be equal to listing price"
        );
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }
}
