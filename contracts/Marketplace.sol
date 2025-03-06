// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./KYCRegistry.sol";
import "./ERC3643Token.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Marketplace is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IKYCRegistry public kycRegistry;
    ERC3643Token public rwaToken;
    AggregatorV3Interface public priceFeed;
    
    struct Listing {
        address seller;
        uint256 amount;
        uint256 priceInUSD;
        bool active;
    }
    
    struct Auction {
        address seller;
        uint256 amount;
        uint256 minBid;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool active;
    }
    
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Auction) public auctions;
    uint256 public listingCounter;
    uint256 public auctionCounter;
    
    event Listed(uint256 indexed listingId, address indexed seller, uint256 amount, uint256 priceInUSD);
    event Sold(uint256 indexed listingId, address indexed buyer, uint256 amount);
    event Cancelled(uint256 indexed listingId);
    event AuctionStarted(uint256 indexed auctionId, address indexed seller, uint256 amount, uint256 minBid, uint256 endTime);
    event NewBid(uint256 indexed auctionId, address indexed bidder, uint256 bidAmount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    
    constructor(address kycRegistryAddress, address tokenAddress, address priceFeedAddress) {
        _grantRole(ADMIN_ROLE, msg.sender);
        kycRegistry = IKYCRegistry(kycRegistryAddress);
        rwaToken = ERC3643Token(tokenAddress);
        priceFeed = AggregatorV3Interface(priceFeedAddress);
    }
    
    function listAsset(uint256 amount, uint256 priceInUSD) external {
        require(kycRegistry.isKYCVerified(msg.sender), "Seller must be KYC verified");
        require(rwaToken.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        rwaToken.transferFrom(msg.sender, address(this), amount);
        listings[listingCounter] = Listing(msg.sender, amount, priceInUSD, true);
        emit Listed(listingCounter, msg.sender, amount, priceInUSD);
        listingCounter++;
    }
    
    function buyAsset(uint256 listingId) external payable {
        Listing storage listing = listings[listingId];
        require(kycRegistry.isKYCVerified(msg.sender), "Buyer must be KYC verified");
        require(listing.active, "Listing is not active");
        require(msg.value >= getPriceInETH(listing.priceInUSD), "Insufficient payment");
        listing.active = false;
        rwaToken.transfer(msg.sender, listing.amount);
        payable(listing.seller).transfer(msg.value);
        emit Sold(listingId, msg.sender, listing.amount);
    }
    
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(msg.sender == listing.seller, "Only seller can cancel");
        require(listing.active, "Listing is not active");
        listing.active = false;
        rwaToken.transfer(listing.seller, listing.amount);
        emit Cancelled(listingId);
    }
    
    function startAuction(uint256 amount, uint256 minBid, uint256 duration) external {
        require(kycRegistry.isKYCVerified(msg.sender), "Seller must be KYC verified");
        require(rwaToken.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        rwaToken.transferFrom(msg.sender, address(this), amount);
        uint256 endTime = block.timestamp + duration;
        auctions[auctionCounter] = Auction(msg.sender, amount, minBid, 0, address(0), endTime, true);
        emit AuctionStarted(auctionCounter, msg.sender, amount, minBid, endTime);
        auctionCounter++;
    }
    
    function placeBid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        require(kycRegistry.isKYCVerified(msg.sender), "Bidder must be KYC verified");
        require(auction.active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");
        
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }
        
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
        emit NewBid(auctionId, msg.sender, msg.value);
    }
    
    function endAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.endTime, "Auction is still ongoing");
        require(auction.active, "Auction is not active");
        auction.active = false;
        
        if (auction.highestBidder != address(0)) {
            rwaToken.transfer(auction.highestBidder, auction.amount);
            payable(auction.seller).transfer(auction.highestBid);
            emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
        } else {
            rwaToken.transfer(auction.seller, auction.amount);
        }
    }
    
    function getPriceInETH(uint256 priceInUSD) public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price feed");
        return (priceInUSD * 1e18) / uint256(price);
    }
}
