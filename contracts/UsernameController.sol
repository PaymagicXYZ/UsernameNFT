pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Oracle.sol";
import "./UsernameNFT.sol";

/**
 * @title UsernameController
 * @dev The UsernameController contract handles the registration, renewal, and management of usernames.
 * It interacts with the Oracle contract to determine the price of registering a username and the
 * UsernameNFT contract to mint and manage the NFTs representing the registered usernames.
 */
contract UsernameController is Ownable {
    Oracle public oracle;
    UsernameNFT public usernameNFT;

    error InsufficientNativeError();
    error NotTokenOwnerError();
    error FailedWithdrawError();
    error NameAlreadyActiveError();
    error OnlyNFTOwnerError();

    modifier onlyNFTOwner(uint256 tokenId) {
        if (msg.sender != usernameNFT.ownerOf(tokenId)) {
            revert OnlyNFTOwnerError();
        }
        _;
    }

    constructor(Oracle _oracle, UsernameNFT _usernameNFT) {
        oracle = _oracle;
        usernameNFT = _usernameNFT;
    }

    /**
     * @notice Registers a new username and mints an NFT if the name is available.
     * @param name string memory - The desired username.
     * @param duration uint96 - The duration for which the username will be registered
     * @return uint - The token ID of the minted NFT.
     */
    function register(
        string memory name,
        uint96 duration
    ) external payable returns (uint) {
        uint8 nameLength = uint8(bytes(name).length);
        uint256 price = oracle.price(nameLength, duration);
        if (msg.value < price) revert InsufficientNativeError();
        uint256 tokenId = usernameNFT.mint(msg.sender, name, duration);
        return tokenId;
    }

    /**
     * @notice Renews the registration of a username by updating its expiry.
     * @param tokenId The token ID of the NFT representing the username.
     * @param duration The additional duration for which the username will be registered
     * @return uint The token ID of the updated NFT.
     */
    function renew(
        uint256 tokenId,
        uint96 duration
    ) external payable returns (uint) {
        (
            uint96 mintTimestamp,
            uint96 _duration,
            address resolveAddress,
            string memory name
        ) = usernameNFT.tokenData(tokenId);

        bool isExpired = usernameNFT.isExpired(tokenId);

        uint256 price = oracle.price(uint8(bytes(name).length), duration);
        if (msg.value < price) revert InsufficientNativeError();

        if (usernameNFT.ownerOf(tokenId) != msg.sender)
            revert NotTokenOwnerError();

        if (!isExpired) {
            uint96 oldMintTimestamp = mintTimestamp;
            uint96 newDuration = _duration + duration;
            usernameNFT.updateTokenData(
                tokenId,
                UsernameNFT.TokenData({
                    resolveAddress: resolveAddress,
                    mintTimestamp: oldMintTimestamp,
                    duration: newDuration,
                    name: name
                })
            );
        }

        if (isExpired) {
            usernameNFT.updateTokenData(
                tokenId,
                UsernameNFT.TokenData({
                    resolveAddress: resolveAddress,
                    mintTimestamp: uint96(block.timestamp),
                    duration: duration,
                    name: name
                })
            );
        }

        return tokenId;
    }

    /**
     * @notice Sets the Oracle instance to be used by the contract.
     * @dev This function can only be called by the contract owner.
     * @param _oracle The address of the Oracle instance to be set.
     */
    function setOracle(Oracle _oracle) external onlyOwner {
        oracle = _oracle;
    }

    /**
     * @notice Withdraws the accumulated Ether balance from the contract to the contract owner's address
     */
    function withdraw() external {
        (bool sent, ) = owner().call{value: address(this).balance}("");
        if (!sent) {
            revert FailedWithdrawError();
        }
    }
}
