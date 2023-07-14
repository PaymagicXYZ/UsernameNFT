pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UsernameController} from "./UsernameController.sol";
import {Base64} from "solady/src/utils/Base64.sol";
import {ERC165Storage} from "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

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

contract ERC634 is IERC634, ERC165Storage {
    mapping(bytes32 => mapping(string => string)) private _textRecords;

    constructor() {
        ERC165Storage._registerInterface(type(IERC634).interfaceId);
    }

    function text(
        bytes32 node,
        string memory key
    ) public view override returns (string memory) {
        return _textRecords[node][key];
    }

    function setText(
        bytes32 node,
        string memory key,
        string memory value
    ) public override {
        require(
            msg.sender == ownerOf(uint256(node)),
            "TextRecords: caller is not the owner"
        );
        _textRecords[node][key] = value;
    }
}

/**
 * @title UsernameNFT
 * @dev UsernameNFT contract represents the NFTs for usernames. Each NFT represents a unique username
 * and has an associated resolved address. The contract also stores the duration for which the username
 * is registered and the timestamp when it was minted or renewed.
 */
abstract contract UsernameNFT is ERC721, Ownable, ERC634 {
    using Base64 for bytes;

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
        address resolveAddress;
        string name;
    }

    mapping(uint256 => TokenData) public tokenData;
    mapping(address => uint256) public primaryNameTokenId;

    event NameRegistered(
        address indexed resolveAddress,
        string name,
        uint256 tokenId
    );
    event TokenDataUpdated(
        address indexed resolveAddress,
        string name,
        uint256 tokenId
    );
    event ResolveAddressUpdated(
        address indexed oldResolveAddress,
        address indexed newResolveAddress,
        string name,
        uint256 tokenId
    );
    event PrimaryNameUpdated(address indexed addr, string newPrimaryName);

    error OnlyControllerError();
    error OnlyNFTOwnerError();
    error NameAlreadyRegisteredError();
    error NameNotRegisteredError();
    error AddressNotRegisteredError();
    error ZeroAddressNotAvailableError();
    error InvalidTokenError();

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

    modifier onlyResolveAddress(uint256 tokenId) {
        if (msg.sender != tokenData[tokenId].resolveAddress) {
            revert AddressNotRegisteredError();
        }
        _;
    }

    /**
     * @notice Sets the controller contract address.
     * @param _controller address - The address of the controller contract.
     * @dev The controller contract is responsible for minting and updating token data.
     */
    function setController(address _controller) external virtual onlyOwner {
        controller = UsernameController(_controller);
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // Token management functions:
    // ────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Mints a new NFT for a given name if it's available.
     * @param to The address of the user who will own the NFT.
     * @param name The desired username.
     * @param duration The duration for which the username will be registered.
     * @return uint256 The token ID of the minted NFT.
     * @dev This function can only be called by the controller contract. It checks if the name is available
     * and mints a new NFT with the given token data if it is.
     */
    function mint(
        address to,
        string memory name,
        uint96 duration
    ) external virtual onlyController returns (uint256) {
        uint256 tokenId = nameToTokenId(name);

        if (_exists(tokenId)) {
            if (!isExpired(tokenId)) {
                revert NameAlreadyRegisteredError();
            } else {
                _burn(tokenId);
            }
        }

        totalSupply++;
        _safeMint(to, tokenId);
        tokenData[tokenId] = TokenData({
            resolveAddress: to,
            mintTimestamp: uint96(block.timestamp),
            duration: duration,
            name: name
        });

        //if primary name not set for resolve address, set it
        if (primaryNameTokenId[to] == 0) {
            primaryNameTokenId[to] = tokenId;
        }

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
        if (data.resolveAddress == address(0)) {
            revert ZeroAddressNotAvailableError();
        }
        emit TokenDataUpdated(data.resolveAddress, data.name, tokenId);
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // Name and address resolution functions:
    // ────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the resolved address for a given username.
     * @param name The username to be resolved.
     * @return address The resolved address of the username.
     * @dev This function returns the resolved address for a given username if it is registered and not expired.
     * Otherwise, it returns the zero address.
     */
    function resolveName(
        string memory name
    ) external view virtual returns (address) {
        uint256 tokenId = nameToTokenId(name);
        if (!_exists(tokenId) || isExpired(tokenId)) {
            return address(0);
        }
        return tokenData[tokenId].resolveAddress;
    }

    /**
     * @notice Returns the username for a given resolved address.
     * @param addr The owner address to be resolved.
     * @return string memory The username associated with the resolved address.
     * @dev This function returns the username associated with a given resolved address if it is registered and not expired.
     * Otherwise, it returns an empty string.
     */
    function resolveAddress(
        address addr
    ) public view virtual returns (string memory) {
        uint256 tokenId = primaryNameTokenId[addr];
        if (isExpired(tokenId)) {
            return "";
        }
        return tokenData[tokenId].name;
    }

    /**
     * @notice Converts a given name to its corresponding token ID.
     * @param name The name to be converted.
     * @return uint256 The token ID corresponding to the given name.
     * @dev This function calculates the token ID by hashing the given name using the keccak256 hash function.
     */
    function nameToTokenId(
        string memory name
    ) public pure virtual returns (uint256) {
        return uint256(keccak256(abi.encodePacked(name)));
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // Token data update functions:
    // ────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Updates the primary name for a given resolved address.
     * @param tokenId The token ID to be the primary name of the resolved address.
     * @dev This function can only be called by resolved address of the NFT. It updates the primary name
     * for the given resolveAddress with the provided tokenId.
     */
    function updatePrimaryName(
        uint256 tokenId
    ) external virtual onlyResolveAddress(tokenId) {
        primaryNameTokenId[msg.sender] = tokenId;
        emit PrimaryNameUpdated(msg.sender, tokenData[tokenId].name);
    }

    /**
     * @notice Updates the resolved address for a given NFT.
     * @param tokenId The token ID of the NFT to be updated.
     * @param newResolveAddress The new resolved address.
     * @dev This function can only be called by the owner of the NFT. It updates the resolved address
     * for the given tokenId with the provided newResolvedAddress. It also updates the primary name
     * for the old and new resolved addresses if needed.
     */
    function updateResolveAddress(
        uint256 tokenId,
        address newResolveAddress
    ) external virtual onlyNFTOwner(tokenId) {
        if (newResolveAddress == address(0)) {
            revert ZeroAddressNotAvailableError();
        }

        address oldResolveAddress = tokenData[tokenId].resolveAddress;
        tokenData[tokenId].resolveAddress = newResolveAddress;

        // Update primary name for old resolve address if it was the primary name
        if (primaryNameTokenId[oldResolveAddress] == tokenId) {
            primaryNameTokenId[oldResolveAddress] = 0;
        }

        // Update primary name for new resolve address if not set
        if (primaryNameTokenId[newResolveAddress] == 0) {
            primaryNameTokenId[newResolveAddress] = tokenId;
        }

        emit ResolveAddressUpdated(
            oldResolveAddress,
            newResolveAddress,
            tokenData[tokenId].name,
            tokenId
        );
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // Token information and utility functions:
    // ────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the Unix timestamp of when the given tokenId expires.
     * @param tokenId The token ID of the NFT.
     * @return uint The Unix timestamp of when the tokenId expires.
     * @dev This function calculates the expiration timestamp by adding the duration to the mint timestamp
     * of the given tokenId.
     */
    function nameExpires(uint256 tokenId) public view virtual returns (uint) {
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
    function isExpired(uint256 tokenId) public view virtual returns (bool) {
        return block.timestamp > nameExpires(tokenId);
    }

    /**
     * @notice Checks if a given name is available for registration.
     * @param name The name to be checked for availability.
     * @return bool True if the name is available, false otherwise.
     * @dev This function checks if the given name is not registered or if the associated tokenId is expired.
     */
    function available(
        string memory name
    ) external view virtual returns (bool) {
        return isExpired(nameToTokenId(name));
    }

    /**
     * @notice Returns the display name for a given address.
     * @param tokenId The token ID to be resolved.
     * @return string memory The display name associated with the address.
     * @dev This function first resolves the address to its associated username using the resolveAddress function.
     * If an active, valid username is found, it appends the domain to the username and returns the resulting display name.
     * Example: If the username is "alice" and the domain is "example", the display name will be "alice.example".
     */
    function getDisplayName(
        uint256 tokenId
    ) public view virtual returns (string memory) {
        return string(abi.encodePacked(tokenData[tokenId].name, ".", domain));
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // Metadata and SVG generation functions:
    // ────────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Generates an SVG image for a given tokenId.
     * @param tokenId The token ID to be used for generating the SVG.
     * @return string memory The generated SVG image as a string.
     * @dev This function generates an SVG image for the given tokenId by concatenating
     * predefined SVG parts and the tokenId as a string. The resulting SVG image is returned.
     */
    function generateSVG(
        uint256 tokenId
    ) internal view virtual returns (string memory);

    /**
     * @notice Generates a JSON string containing the attributes for a given token ID.
     * @param tokenId The token ID to be used for generating the attributes.
     * @return string memory The generated JSON string containing the attributes.
     * @dev This function generates a JSON string containing various attributes associated with the token ID.
     * The attributes include tokenId, name, resolvedAddress, and expiresAt.
     */
    function generateAttributes(
        uint256 tokenId
    ) internal view virtual returns (string memory);

    /**
     * @notice Generates a JSON string containing metadata for a given token ID.
     * @param tokenId The token ID to be used for generating the metadata.
     * @return string memory The generated JSON string containing the metadata.
     * @dev This function generates a JSON string containing metadata associated with the token ID.
     * The metadata includes the name, description, image (as a base64-encoded SVG), and attributes.
     */
    function generateJSON(
        uint256 tokenId
    ) internal view virtual returns (string memory);

    /**
     * @notice Returns the URI for a given NFT.
     * @param tokenId The token ID of the NFT.
     * @return string memory The URI of the NFT.
     * @dev This function returns the URI of the NFT by encoding the generated JSON metadata as a base64 string.
     * The URI can be used to retrieve metadata associated with the NFT, such as a JSON file containing
     * information about the NFT's properties, image, and other attributes.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) {
            revert InvalidTokenError();
        }

        string memory json = Base64.encode(bytes(generateJSON(tokenId)));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
