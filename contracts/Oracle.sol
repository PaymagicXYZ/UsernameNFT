pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Oracle
 * @dev Oracle contract returns a price set by the oracle contract owner.
 * The owner can change the fee structure. The price is determined by the username length and is multiplied by the duration.
 */
abstract contract Oracle is Ownable {
    uint32 constant SECONDS_PER_YEAR = 31_536_000;
    uint64 constant FACTOR = 10 ** 18;

    struct YearlyUsernameFees {
        uint64 lengthThree;
        uint64 lengthFour;
        uint64 lengthFiveOrMore;
    }

    YearlyUsernameFees public yearlyUsernameFees;

    constructor(YearlyUsernameFees memory _yearlyUsernameFees) {
        yearlyUsernameFees = _yearlyUsernameFees;
    }

    event FeesUpdated(YearlyUsernameFees oldFees, YearlyUsernameFees newFees);

    error InvalidUsernameLength();

    /**
     * @notice Calculate the price for a username based on its length and the desired duration.
     * @param usernameLength The length of the username.
     * @param durationInSeconds The desired duration in seconds.
     * @return The price in wei.
     * @dev Reverts if the username length is less than 3.
     */
    function price(
        uint8 usernameLength,
        uint128 durationInSeconds
    ) external view virtual returns (uint);

    /**
     * @notice Change the fee structure for username pricing.
     * @param newFees The new fee structure.
     * @dev Emits a FeesUpdated event with the old and new fee structures.
     * @dev Only callable by the contract owner.
     */
    function changeFees(
        YearlyUsernameFees calldata newFees
    ) external onlyOwner {
        YearlyUsernameFees memory oldFees = yearlyUsernameFees;
        yearlyUsernameFees = newFees;
        emit FeesUpdated(oldFees, newFees);
    }
}
