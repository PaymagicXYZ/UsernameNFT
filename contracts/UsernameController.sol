pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
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
    error InvalidDurationError();

    uint96 SECONDS_PER_YEAR = 31_536_000;

    modifier checkDuration(uint8 durationInYears) {
        if (durationInYears < 1 || durationInYears > 3) {
            revert InvalidDurationError();
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
     * @param resolvedAddress address - The address of the user who will own the NFT.
     * @param durationInYears uint8 - The duration for which the username will be registered (1-3 years).
     * @return uint - The token ID of the minted NFT.
     */
    function register(
        string memory name,
        address resolvedAddress,
        uint8 durationInYears
    ) external payable checkDuration(durationInYears) returns (uint) {
        uint256 nameLength = bytes(name).length;
        uint256 price = oracle.price(nameLength, durationInYears);
        if (msg.value < price) revert InsufficientNativeError();
        uint256 tokenId = usernameNFT.mint(
            msg.sender,
            resolvedAddress,
            name,
            totalSeconds(durationInYears)
        );
        return tokenId;
    }

    /**
     * @notice Renews the registration of a username by updating its expiry.
     * @param tokenId The token ID of the NFT representing the username.
     * @param durationInYears The additional duration for which the username will be registered (1-3 years).
     * @return uint The token ID of the updated NFT.
     */
    function renew(
        address resolvedAddress,
        uint256 tokenId,
        uint8 durationInYears
    ) external payable checkDuration(durationInYears) returns (uint) {
        UsernameNFT.TokenData memory data = usernameNFT.getTokenData(tokenId);

        bool isExpired = data.duration + data.mintTimestamp < block.timestamp
            ? true
            : false;

        string memory name = usernameNFT.resolvedAddressToName(
            data.resolvedAddress
        );

        uint256 price = oracle.price(bytes(name).length, durationInYears);
        if (msg.value < price) revert InsufficientNativeError();

        if (usernameNFT.ownerOf(tokenId) != msg.sender)
            revert NotTokenOwnerError();

        if (!isExpired) {
            uint96 oldMintTimestamp = data.mintTimestamp;
            uint96 newDuration = data.duration + totalSeconds(durationInYears);
            usernameNFT.updateTokenData(
                tokenId,
                UsernameNFT.TokenData({
                    resolvedAddress: resolvedAddress,
                    mintTimestamp: oldMintTimestamp,
                    duration: newDuration
                })
            );
        }

        if (isExpired) {
            if (usernameNFT.resolveName(name) != address(0)) {
                revert NameAlreadyActiveError();
            }
            usernameNFT.updateTokenData(
                tokenId,
                UsernameNFT.TokenData({
                    resolvedAddress: resolvedAddress,
                    mintTimestamp: uint96(block.timestamp),
                    duration: totalSeconds(durationInYears)
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

    /**
     * @notice Converts the duration in years to seconds.
     * @param durationInYears uint96 - The duration in years.
     * @return uint96 - The duration in seconds.
     */
    function totalSeconds(
        uint96 durationInYears
    ) internal view returns (uint96) {
        return durationInYears * SECONDS_PER_YEAR;
    }
}
