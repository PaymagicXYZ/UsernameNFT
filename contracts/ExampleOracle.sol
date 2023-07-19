pragma solidity ^0.8.0;

import {Oracle} from "./Oracle.sol";

contract ExampleOracle is Oracle {
    constructor()
        Oracle(
            YearlyUsernameFees({
                lengthThree: 0.32 ether,
                lengthFour: 0.08 ether,
                lengthFiveOrMore: 0.0025 ether
            })
        )
    {}

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
    ) external view virtual override returns (uint) {
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
}
