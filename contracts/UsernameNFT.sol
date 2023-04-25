pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UsernameController.sol";

import "hardhat/console.sol";

/**
 * @title UsernameNFT
 * @dev UsernameNFT contract represents the NFTs for usernames.
 */
contract UsernameNFT is ERC721, Ownable {
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    uint256 public totalSupply;

    UsernameController public controller;

    struct TokenData {
        uint96 mintTimestamp;
        uint96 duration;
        address resolvedAddress;
    }

    mapping(uint256 => TokenData) public tokenData;
    mapping(string => uint256) public nameToTokenId;
    mapping(address => string) public resolvedAddressToName;

    event NameRegistered(
        address indexed resolvedAddress,
        string name,
        uint256 tokenId
    );
    event NameRenewed(
        address indexed resolvedAddress,
        string name,
        uint256 tokenId
    );
    event ResolveAddressUpdated(
        address indexed oldResolvedAddress,
        address indexed newResolvedAddress,
        string name,
        uint256 tokenId
    );

    error OnlyControllerError();
    error NameAlreadyRegisteredError();
    error NameNotRegisteredError();
    error AddressNotRegisteredError();

    modifier onlyController() {
        if (msg.sender != address(controller)) {
            revert OnlyControllerError();
        }
        _;
    }

    /**
     * @notice Sets the controller contract address.
     * @param _controller address - The address of the controller contract.
     */
    function setController(address _controller) external onlyOwner {
        controller = UsernameController(_controller);
    }

    /**
     * @notice Mints a new NFT for a given name if it's available.
     * @param to The address of the user who will own the NFT.
     * @param name The desired username.
     * @param duration The duration for which the username will be registered.
     * @return uint256 The token ID of the minted NFT.
     */
    function mint(
        address to,
        address resolvedAddress,
        string memory name,
        uint96 duration
    ) external onlyController returns (uint256) {
        if (nameToTokenId[name] != 0) {
            revert NameAlreadyRegisteredError();
        }
        totalSupply++;
        uint256 tokenId = totalSupply;
        _safeMint(to, tokenId);
        tokenData[tokenId] = TokenData({
            resolvedAddress: resolvedAddress,
            mintTimestamp: uint96(block.timestamp),
            duration: duration
        });
        nameToTokenId[name] = tokenId;
        resolvedAddressToName[resolvedAddress] = name;
        emit NameRegistered(to, name, tokenId);
        return tokenId;
    }

    /**
     * @notice Updates the token data for a given NFT.
     * @param tokenId The token ID of the NFT to be updated.
     * @param data The updated token data.
     */
    function updateTokenData(
        uint256 tokenId,
        TokenData memory data
    ) external onlyController {
        tokenData[tokenId] = data;
        emit NameRenewed(
            data.resolvedAddress,
            resolvedAddressToName[data.resolvedAddress],
            tokenId
        );
    }

    /**
     * @notice Updates the primary name associated with the caller's address.
     * @param name The new primary name to be associated with the caller's address.
     */
    function updatePrimaryName(string memory name) external {
        uint256 tokenId = nameToTokenId[name];
        require(tokenId != 0, "Name not registered");
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the name");
        resolvedAddressToName[msg.sender] = name;
    }

    /**
     * @notice Updates the resolved address for a given NFT.
     * @param tokenId The token ID of the NFT to be updated.
     * @param newResolvedAddress The new resolved address.
     */
    function updateResolveAddress(
        uint256 tokenId,
        address newResolvedAddress
    ) external onlyController {
        TokenData storage data = tokenData[tokenId];
        address oldResolvedAddress = data.resolvedAddress;
        data.resolvedAddress = newResolvedAddress;
        emit ResolveAddressUpdated(
            oldResolvedAddress,
            newResolvedAddress,
            resolvedAddressToName[oldResolvedAddress],
            tokenId
        );
    }

    /**
     * @notice Returns the token data for a given NFT.
     * @param tokenId The token ID of the NFT.
     * @return TokenData memory The token data of the NFT.
     */
    function getTokenData(
        uint256 tokenId
    ) external view returns (TokenData memory) {
        return tokenData[tokenId];
    }

    /**
     * @notice Returns the resolved address for a given username.
     * @param name The username to be resolved.
     * @return address The resolved address of the username.
     */
    function resolveName(string memory name) external view returns (address) {
        uint256 tokenId = nameToTokenId[name];
        if (tokenId == 0) {
            revert NameNotRegisteredError();
        }
        TokenData memory data = tokenData[tokenId];
        if (block.timestamp > data.mintTimestamp + data.duration) {
            return address(0);
        }
        return data.resolvedAddress;
    }

    /**
     * @notice Returns the username for a given resolved address.
     * @param addr The owner address to be resolved.
     * @return string memory The username associated with the resolved address.
     */
    function resolveAddress(
        address addr
    ) external view returns (string memory) {
        string memory name = resolvedAddressToName[addr];
        console.log(name);
        if (bytes(name).length == 0) {
            revert AddressNotRegisteredError();
        }
        uint256 tokenId = nameToTokenId[name];
        TokenData memory data = tokenData[tokenId];
        if (block.timestamp > data.mintTimestamp + data.duration) {
            return "";
        }
        return name;
    }

    /**
     * @notice Returns the Unix timestamp of when the given tokenId expires.
     * @param tokenId The token ID of the NFT.
     * @return uint The Unix timestamp of when the tokenId expires.
     */
    function nameExpires(uint256 tokenId) external view returns (uint) {
        TokenData memory data = tokenData[tokenId];
        return data.mintTimestamp + data.duration;
    }

    /**
     * @notice Checks if a given name is available for registration.
     * @param name The name to be checked for availability.
     * @return bool True if the name is available, false otherwise.
     */
    function available(string memory name) external view returns (bool) {
        uint256 tokenId = nameToTokenId[name];
        if (tokenId == 0) {
            return true;
        }
        TokenData memory data = tokenData[tokenId];
        return block.timestamp > data.mintTimestamp + data.duration;
    }

    /**
     * @notice Returns the URI for a given NFT.
     * @param tokenId The token ID of the NFT.
     * @return string memory The URI of the NFT.
     */
    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        return Strings.toString(tokenId);
    }
}
