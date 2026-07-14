// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title RWA Marketplace
/// @notice Simple marketplace for buying and selling ERC20 property tokens on Arbitrum.
contract RWAMarketplace is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        address token;
        uint256 amount;
        uint256 pricePerUnit;
        bool active;
    }

    mapping(uint256 => Listing) public listings;

    uint256 public nextListingId;
    uint256 public minimumListingPrice = 1 wei;

    event PropertyListed(
        uint256 indexed listingId,
        address indexed seller,
        address token,
        uint256 amount,
        uint256 pricePerUnit
    );

    event PropertyPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice
    );

    event ListingCanceled(uint256 indexed listingId);
    event MinimumListingPriceUpdated(uint256 previousPrice, uint256 newPrice);

    function listForSale(
        address token,
        uint256 amount,
        uint256 pricePerUnit
    ) external whenNotPaused returns (uint256) {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be positive");
        require(
            pricePerUnit >= minimumListingPrice,
            "Price below minimum"
        );

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 listingId = nextListingId;

        listings[listingId] = Listing({
            seller: msg.sender,
            token: token,
            amount: amount,
            pricePerUnit: pricePerUnit,
            active: true
        });

        emit PropertyListed(
            listingId,
            msg.sender,
            token,
            amount,
            pricePerUnit
        );

        nextListingId++;

        return listingId;
    }

    function purchase(
        uint256 listingId,
        uint256 amount
    ) external payable nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(
            amount > 0 && amount <= listing.amount,
            "Invalid purchase amount"
        );

        uint256 totalValue = amount * listing.pricePerUnit;
        require(msg.value == totalValue, "Incorrect payment amount");

        listing.amount -= amount;

        if (listing.amount == 0) {
            listing.active = false;
        }

        payable(listing.seller).transfer(totalValue);
        IERC20(listing.token).safeTransfer(msg.sender, amount);

        emit PropertyPurchased(
            listingId,
            msg.sender,
            amount,
            totalValue
        );
    }

    function cancelListing(
        uint256 listingId
    ) external nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(
            msg.sender == listing.seller || msg.sender == owner(),
            "Not authorized"
        );

        listing.active = false;

        IERC20(listing.token).safeTransfer(
            listing.seller,
            listing.amount
        );

        emit ListingCanceled(listingId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setMinimumListingPrice(
        uint256 newMinimumPrice
    ) external onlyOwner {
        require(newMinimumPrice > 0, "Minimum price must be positive");

        uint256 previousPrice = minimumListingPrice;
        minimumListingPrice = newMinimumPrice;

        emit MinimumListingPriceUpdated(
            previousPrice,
            newMinimumPrice
        );
    }

    function withdraw(
        address payable recipient
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        recipient.transfer(address(this).balance);
    }
}