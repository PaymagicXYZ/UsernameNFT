pragma solidity ^0.8.0;

/**
 * @title DummyOracle
 * @dev DummyOracle contract returns a fixed price for demonstration purposes.
 */
contract DummyOracle {
    /**
     * @notice Returns a fixed price for demonstration purposes.
     * @return uint - The fixed price (1 ether).
     */
    function price() external pure returns (uint) {
        return 1 ether;
    }
}
