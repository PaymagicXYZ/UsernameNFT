pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DummyOracle.sol";
import "./UsernameNFT.sol";

/**
 * @title UsernameController
 * @dev UsernameController contract handles the registration and renewal of usernames.
 */
contract UsernameController is Ownable {
    DummyOracle public dummyOracle;
    UsernameNFT public usernameNFT;

    constructor(DummyOracle _dummyOracle, UsernameNFT _usernameNFT) {
        dummyOracle = _dummyOracle;
        usernameNFT = _usernameNFT;
    }

    /**
     * @notice Registers a new username and mints an NFT if the name is available.
     * @param name string memory - The desired username.
     * @param owner address - The address of the user who will own the NFT.
     * @param duration uint96 - The duration for which the username will be registered.
     * @return uint - The token ID of the minted NFT.
     */
    function register(
        string memory name,
        address owner,
        uint96 duration
    ) external payable returns (uint) {
        uint256 price = dummyOracle.price();
        require(msg.value >= price, "Not enough Ether sent for registration");
        uint256 tokenId = usernameNFT.mint(owner, name, duration);
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
        uint256 price = dummyOracle.price();
        require(msg.value >= price, "Not enough Ether sent for registration");

        UsernameNFT.TokenData memory data = usernameNFT.getTokenData(tokenId);
        require(data.owner == msg.sender, "Only the owner can renew the token");

        data.duration += duration;
        usernameNFT.updateTokenData(tokenId, data);

        return tokenId;
    }

    /**
     * @notice Withdraws the accumulated Ether balance from the contract to the contract owner's address
     */
    function withdraw() public {
        payable(owner()).transfer(address(this).balance);
    }
}
