pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

/**
 * @title Oracle
 * @dev Oracle contract returns a price set by the oracle contract owner.
 * The owner can change the base price. The price is inversely proportional to the natural logarithm of the username length.
 */
contract Oracle is Ownable {
    uint public basePrice;

    event BasePriceUpdated(uint oldBasePrice, uint newBasePrice);

    constructor(uint _basePrice) {
        basePrice = _basePrice;
    }

    error UsernameTooShort();

    /**
     * @notice Calculates and returns the price for a username based on its length. The price is determined by the natural logarithm of the username length and is inversely proportional to the length.
     * @dev The function reverts if the username length is less than 3.The base price is returned if the username length is exactly 3.
     * @param usernameLength The length of the username.
     * @return uint - The current price.
     */
    function price(uint usernameLength) external view returns (uint) {
        if (usernameLength < 3) {
            revert UsernameTooShort();
        }

        if (usernameLength == 3) {
            return basePrice;
        }

        // Calculate the natural logarithm of the username length
        int128 lnUsernameLength = ABDKMath64x64.ln(
            ABDKMath64x64.fromUInt(usernameLength)
        );

        // Calculate the factor as 2 divided by the username length
        int128 factor = ABDKMath64x64.div(
            ABDKMath64x64.fromUInt(2),
            ABDKMath64x64.fromUInt(usernameLength)
        );

        // Calculate the final price by multiplying the base price, ln(usernameLength), and the factor
        return
            ABDKMath64x64.toUInt(
                ABDKMath64x64.mul(
                    ABDKMath64x64.fromUInt(basePrice),
                    ABDKMath64x64.mul(lnUsernameLength, factor)
                )
            );
    }

    /**
     * @notice Allows the owner to set a new base price.
     * @param newBasePrice The new base price to be set.
     */
    function setPrice(uint newBasePrice) external onlyOwner {
        uint oldBasePrice = basePrice;
        basePrice = newBasePrice;

        emit BasePriceUpdated(oldBasePrice, newBasePrice);
    }
}
