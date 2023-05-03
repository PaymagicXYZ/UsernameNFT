pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Oracle
 * @dev Oracle contract returns a price set by the oracle contract owner.
 * The owner can change the fee structure. The price is determined by the username length and is multiplied by the duration.
 */
contract Oracle is Ownable {
    uint32 constant SECONDS_PER_YEAR = 31_536_000;
    uint64 constant FACTOR = 10 ** 18;

    struct YearlyUsernameFees {
        uint64 lengthThree;
        uint64 lengthFour;
        uint64 lengthFiveOrMore;
    }

    YearlyUsernameFees public yearlyUsernameFees;

    constructor() {
        yearlyUsernameFees = YearlyUsernameFees({
            lengthThree: 0.32 ether,
            lengthFour: 0.8 ether,
            lengthFiveOrMore: 0.0025 ether
        });
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
    ) external view returns (uint) {
        if (usernameLength < 3) {
            revert InvalidUsernameLength();
        }

        uint fee;
        if (usernameLength == 3) {
            fee = yearlyUsernameFees.lengthThree;
        } else if (usernameLength == 4) {
            fee = yearlyUsernameFees.lengthFour;
        } else {
            fee = yearlyUsernameFees.lengthFiveOrMore;
        }

        uint256 durationInYears = (durationInSeconds * FACTOR) /
            SECONDS_PER_YEAR;

        return (fee * durationInYears) / FACTOR;
    }

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
