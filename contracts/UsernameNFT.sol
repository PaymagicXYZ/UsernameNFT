pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UsernameController.sol";

/**
 * @title UsernameNFT
 * @dev UsernameNFT contract represents the NFTs for usernames. Each NFT represents a unique username
 * and has an associated resolved address. The contract also stores the duration for which the username
 * is registered and the timestamp when it was minted or renewed.
 */
contract UsernameNFT is ERC721, Ownable {
    string public domain;

    constructor(
        string memory name,
        string memory symbol,
        string memory _domain
    ) ERC721(name, symbol) {
        domain = _domain;
    }

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
    event TokenDataUpdated(
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
    error OnlyNFTOwnerError();
    error NameAlreadyRegisteredError();
    error NameNotRegisteredError();
    error AddressNotRegisteredError();
    error ZeroAddressNotAvailableError();

    modifier onlyController() {
        if (msg.sender != address(controller)) {
            revert OnlyControllerError();
        }
        _;
    }

    modifier onlyNFTOwner(uint256 tokenId) {
        if (msg.sender != ownerOf(tokenId)) {
            revert OnlyNFTOwnerError();
        }
        _;
    }

    /**
     * @notice Sets the controller contract address.
     * @param _controller address - The address of the controller contract.
     * @dev The controller contract is responsible for minting and updating token data.
     */
    function setController(address _controller) external onlyOwner {
        controller = UsernameController(_controller);
    }

    /**
     * @notice Mints a new NFT for a given name if it's available.
     * @param to The address of the user who will own the NFT.
     * @param resolvedAddress The address that the username will resolve to.
     * @param name The desired username.
     * @param duration The duration for which the username will be registered.
     * @return uint256 The token ID of the minted NFT.
     * @dev This function can only be called by the controller contract. It checks if the name is available
     * and mints a new NFT with the given token data if it is.
     */
    function mint(
        address to,
        address resolvedAddress,
        string memory name,
        uint96 duration
    ) external onlyController returns (uint256) {
        if (resolvedAddress == address(0) || to == address(0)) {
            revert ZeroAddressNotAvailableError();
        }
        uint256 tokenId = nameToTokenId[name];
        if (tokenId != 0 && !isExpired(tokenId)) {
            revert NameAlreadyRegisteredError();
        }
        totalSupply++;
        tokenId = totalSupply;
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
     * @dev This function can only be called by the controller contract. It updates the token data
     * for the given tokenId with the provided data.
     */
    function updateTokenData(
        uint256 tokenId,
        TokenData memory data
    ) external onlyController {
        tokenData[tokenId] = data;
        if (data.resolvedAddress == address(0)) {
            revert ZeroAddressNotAvailableError();
        }
        emit TokenDataUpdated(
            data.resolvedAddress,
            resolvedAddressToName[data.resolvedAddress],
            tokenId
        );
    }

    // /**
    //  * @notice Updates the primary name associated with the caller's address.
    //  * @param name The new primary name to be associated with the caller's address.
    //  */
    // function updatePrimaryName(string memory name) external onlyController {
    //     uint256 tokenId = nameToTokenId[name];
    //     require(tokenId != 0, "Name not registered");
    //     require(ownerOf(tokenId) == msg.sender, "Not the owner of the name");
    //     resolvedAddressToName[msg.sender] = name;
    // }

    /**
     * @notice Updates the resolved address for a given NFT.
     * @param tokenId The token ID of the NFT to be updated.
     * @param newResolvedAddress The new resolved address.
     * @dev This function can only be called by the owner of the NFT. It updates the resolved address
     * for the given tokenId with the provided newResolvedAddress.
     */
    function updateResolveAddress(
        uint256 tokenId,
        address newResolvedAddress
    ) external onlyNFTOwner(tokenId) {
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
     * @notice Returns the resolved address for a given username.
     * @param name The username to be resolved.
     * @return address The resolved address of the username.
     * @dev This function returns the resolved address for a given username if it is registered and not expired.
     * Otherwise, it returns the zero address.
     */
    function resolveName(string memory name) external view returns (address) {
        uint256 tokenId = nameToTokenId[name];
        if (tokenId == 0 || isExpired(tokenId)) {
            return address(0);
        }
        return tokenData[tokenId].resolvedAddress;
    }

    /**
     * @notice Returns the username for a given resolved address.
     * @param addr The owner address to be resolved.
     * @return string memory The username associated with the resolved address.
     * @dev This function returns the username associated with a given resolved address if it is registered and not expired.
     * Otherwise, it returns an empty string.
     */
    function resolveAddress(address addr) public view returns (string memory) {
        string memory name = resolvedAddressToName[addr];
        uint256 tokenId = nameToTokenId[name];
        if (tokenId == 0 || isExpired(tokenId)) {
            return "";
        }
        return name;
    }

    /**
     * @notice Returns the Unix timestamp of when the given tokenId expires.
     * @param tokenId The token ID of the NFT.
     * @return uint The Unix timestamp of when the tokenId expires.
     * @dev This function calculates the expiration timestamp by adding the duration to the mint timestamp
     * of the given tokenId.
     */
    function nameExpirationTime(uint256 tokenId) public view returns (uint) {
        TokenData memory data = tokenData[tokenId];
        return data.mintTimestamp + data.duration;
    }

    /**
     * @notice Checks if a given tokenId is expired.
     * @param tokenId The token ID of the NFT.
     * @return bool True if the tokenId is expired, false otherwise.
     * @dev This function checks if the current block timestamp is greater than the expiration timestamp
     * of the given tokenId.
     */
    function isExpired(uint256 tokenId) public view returns (bool) {
        return block.timestamp > nameExpirationTime(tokenId);
    }

    /**
     * @notice Checks if a given name is available for registration.
     * @param name The name to be checked for availability.
     * @return bool True if the name is available, false otherwise.
     * @dev This function checks if the given name is not registered or if the associated tokenId is expired.
     */
    function isAvailable(string memory name) external view returns (bool) {
        return nameToTokenId[name] == 0 || isExpired(nameToTokenId[name]);
    }

    /**
     * @notice Returns the display name for a given address.
     * @param addr The address to be resolved.
     * @return string memory The display name associated with the address.
     * @dev This function first resolves the address to its associated username using the resolveAddress function.
     * If an active, valid username is found, it appends the domain to the username and returns the resulting display name.
     * Example: If the username is "alice" and the domain is "example", the display name will be "alice.example".
     */
    function getDisplayName(address addr) public view returns (string memory) {
        string memory name = resolveAddress(addr);
        return string(abi.encodePacked(name, ".", domain));
    }

    /**
     * @notice Returns the URI for a given NFT.
     * @param tokenId The token ID of the NFT.
     * @return string memory The URI of the NFT.
     * @dev This function returns the URI of the NFT by converting the tokenId to a string.
     * The URI can be used to retrieve metadata associated with the NFT, such as a JSON file containing
     * information about the NFT's properties, image, and other attributes.
     * Example: If the tokenId is 1, the returned URI will be "1".
     */
    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        return Strings.toString(tokenId);
    }
}
