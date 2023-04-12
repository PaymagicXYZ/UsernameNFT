pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Oracle
 * @dev Oracle contract returns a fixed price set by the oracle contract owner.
 * The owner can change the price.
 */
contract Oracle is Ownable {
    uint private price_;

    event PriceUpdated(uint oldPrice, uint newPrice);

    constructor(uint _price) {
        price_ = _price;
    }

    /**
     * @notice Returns the current price set by the owner.
     * @return uint - The current price.
     */
    function price() external view returns (uint) {
        return price_;
    }

    /**
     * @notice Allows the owner to set a new price.
     * @param newPrice The new price to be set.
     */
    function setPrice(uint newPrice) external onlyOwner {
        uint oldPrice = price_;
        price_ = newPrice;

        emit PriceUpdated(oldPrice, newPrice);
    }
}
