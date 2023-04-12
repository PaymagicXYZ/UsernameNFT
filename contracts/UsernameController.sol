pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Oracle.sol";
import "./UsernameNFT.sol";

/**
 * @title UsernameController
 * @dev UsernameController contract handles the registration and renewal of usernames.
 */
contract UsernameController is Ownable {
    Oracle public oracle;
    UsernameNFT public usernameNFT;

    error InsufficientNativeError();
    error NotTokenOwnerError();
    error FailedSendError();

    constructor(Oracle _oracle, UsernameNFT _usernameNFT) {
        oracle = _oracle;
        usernameNFT = _usernameNFT;
    }

    /**
     * @notice Registers a new username and mints an NFT if the name is available.
     * @param name string memory - The desired username.
     * @param resolvedAddress address - The address of the user who will own the NFT.
     * @param duration uint96 - The duration for which the username will be registered.
     * @return uint - The token ID of the minted NFT.
     */
    function register(
        string memory name,
        address resolvedAddress,
        uint96 duration
    ) external payable returns (uint) {
        uint256 price = oracle.price();
        if (msg.value < price) revert InsufficientNativeError();
        uint256 tokenId = usernameNFT.mint(
            msg.sender,
            resolvedAddress,
            name,
            duration
        );
        return tokenId;
    }

    /**
     * @notice Renews the registration of a username by updating its expiry.
     * @param tokenId The token ID of the NFT representing the username.
     * @param duration The additional duration for which the username will be registered.
     * @return uint The token ID of the updated NFT.
     */
    function renew(
        uint256 tokenId,
        uint96 duration
    ) external payable returns (uint) {
        uint256 price = oracle.price();
        if (msg.value < price) revert InsufficientNativeError();

        UsernameNFT.TokenData memory data = usernameNFT.getTokenData(tokenId);
        if (data.resolvedAddress != msg.sender) revert NotTokenOwnerError();

        data.duration += duration;
        usernameNFT.updateTokenData(tokenId, data);

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
    function withdraw() public {
        (bool sent, ) = owner().call{value: address(this).balance}("");
        if (!sent) {
            revert FailedSendError();
        }
    }
}
