pragma solidity ^0.8.0;

interface IERC634 {
    function text(
        bytes32 node,
        string calldata key
    ) external view returns (string memory);

    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external;
}
