pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UsernameController.sol";
import "solady/src/utils/LibString.sol";
import "solady/src/utils/Base64.sol";

/**
 * @title UsernameNFT
 * @dev UsernameNFT contract represents the NFTs for usernames. Each NFT represents a unique username
 * and has an associated resolved address. The contract also stores the duration for which the username
 * is registered and the timestamp when it was minted or renewed.
 */
contract UsernameNFT is ERC721, Ownable {
    using LibString for address;
    using LibString for uint256;

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
    function setController(address _controller) external onlyOwner {
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
    ) external onlyController returns (uint256) {
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
    function resolveName(string memory name) external view returns (address) {
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
    function resolveAddress(address addr) public view returns (string memory) {
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
    function nameToTokenId(string memory name) public pure returns (uint256) {
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
    ) external onlyResolveAddress(tokenId) {
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
    ) external onlyNFTOwner(tokenId) {
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
    function nameExpires(uint256 tokenId) public view returns (uint) {
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
        return block.timestamp > nameExpires(tokenId);
    }

    /**
     * @notice Checks if a given name is available for registration.
     * @param name The name to be checked for availability.
     * @return bool True if the name is available, false otherwise.
     * @dev This function checks if the given name is not registered or if the associated tokenId is expired.
     */
    function available(string memory name) external view returns (bool) {
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
    ) public view returns (string memory) {
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
    ) internal view returns (string memory) {
        string[3] memory parts;

        parts[
            0
        ] = '<svg width="1088" height="1088" viewBox="0 0 1088 1088" fill="none" xmlns="http://www.w3.org/2000/svg"> <g filter="url(#filter0_d_2657_6950)"> <g clip-path="url(#clip0_2657_6950)"> <rect x="4" width="1080" height="1080" rx="120" fill="#131315"/> <path d="M283 -31L-14 266H1128.5L260 1134.5" stroke="#282828" stroke-width="29"/> <path d="M280.5 261.5L-14 557H1128.5L260 1425.5" stroke="#282828" stroke-width="29"/> <g clip-path="url(#clip1_2657_6950)"> <path d="M205.125 173.079H187.508V85.6543H205.125V173.079Z" fill="white"/> <path d="M268.783 83.9375C278.508 83.9375 286.454 87.415 292.61 94.3699C298.757 101.325 301.839 110.168 301.839 120.889V173.069H284.221V123.626C284.221 116.897 282.096 111.333 277.844 106.943C273.593 102.553 268.34 100.358 262.078 100.358C255.027 100.358 249.27 102.553 244.797 106.943C240.324 111.333 238.083 116.897 238.083 123.626V173.069H220.466V85.6537H238.083V108.235C240.43 100.711 244.319 94.7763 249.748 90.4408C255.169 86.1052 261.52 83.9375 268.792 83.9375H268.783Z" fill="white"/> <path d="M356.764 83.9375C370.519 83.9375 381.706 88.9595 390.316 98.9945C398.926 109.039 402.45 121.178 400.883 135.44H329.917C331.148 142.513 334.337 148.248 339.483 152.638C344.629 157.027 350.83 159.223 358.101 159.223C363.69 159.223 368.695 157.822 373.115 155.031C377.535 152.24 380.971 148.447 383.433 143.651L398.199 150.326C394.399 157.741 388.97 163.667 381.927 168.12C374.886 172.572 366.773 174.795 357.597 174.795C344.736 174.795 333.938 170.459 325.214 161.797C316.49 153.135 312.123 142.35 312.123 129.461C312.123 116.572 316.4 105.769 324.957 97.0344C333.513 88.3092 344.107 83.9465 356.755 83.9465L356.764 83.9375ZM356.764 99.5093C350.271 99.5093 344.656 101.533 339.899 105.588C335.143 109.635 331.981 114.91 330.422 121.413H383.106C381.653 114.91 378.544 109.635 373.797 105.588C369.041 101.542 363.363 99.5093 356.764 99.5093Z" fill="white"/> <path d="M449.589 83.9375C459.882 83.9375 468.269 86.6743 474.753 92.148C481.236 97.6216 484.488 105.498 484.488 115.759V173.079H466.87V149.811C461.609 166.467 451.042 174.795 435.16 174.795C427.773 174.795 421.626 172.546 416.702 168.039C411.777 163.531 409.323 157.633 409.323 150.335C409.323 141.781 412.282 135.359 418.216 131.087C424.142 126.814 431.697 124.159 440.865 123.129L457.472 121.413C463.735 120.844 466.87 117.99 466.87 112.859C466.87 108.641 465.275 105.272 462.087 102.77C458.898 100.259 454.735 99.0036 449.589 99.0036C444.443 99.0036 439.881 100.376 436.25 103.113C432.618 105.85 430.298 109.842 429.288 115.09L411.839 110.809C413.407 102.598 417.596 96.068 424.425 91.2176C431.246 86.3762 439.633 83.9465 449.589 83.9465V83.9375ZM440.865 160.244C448.136 160.244 454.283 157.759 459.315 152.801C464.346 147.842 466.861 142.052 466.861 135.431V130.644C465.523 132.929 462.273 134.347 457.127 134.916L440.856 136.967C436.604 137.545 433.221 138.818 430.705 140.815C428.189 142.811 426.932 145.52 426.932 148.944C426.932 152.367 428.189 155.104 430.705 157.154C433.221 159.205 436.604 160.234 440.856 160.234L440.865 160.244Z" fill="white"/> <path d="M175.373 173.079H94V85.6543H112.618V156.143H175.373V173.079Z" fill="white"/> <path d="M501.095 83.9379C510.267 83.9379 517.702 76.3556 517.702 67.0022C517.702 57.6488 510.267 50.0664 501.095 50.0664C491.923 50.0664 484.488 57.6488 484.488 67.0022C484.488 76.3556 491.923 83.9379 501.095 83.9379Z" fill="white"/> </g> <rect x="-41" y="749" width="1159" height="237" fill="#18181B"/> <text fill="white" xml:space="preserve" style="white-space: pre" font-family="Arial" font-size="96" letter-spacing="-0.04em"><tspan x="67" y="899.281">';
        parts[1] = getDisplayName(tokenId);
        parts[
            2
        ] = '</tspan></text> </g> </g> <defs> <filter id="filter0_d_2657_6950" x="0" y="0" width="1088" height="1088" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"> <feFlood flood-opacity="0" result="BackgroundImageFix"/> <feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/> <feOffset dy="4"/> <feGaussianBlur stdDeviation="2"/> <feComposite in2="hardAlpha" operator="out"/> <feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/> <feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_2657_6950"/> <feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_2657_6950" result="shape"/> </filter> <clipPath id="clip0_2657_6950"> <rect x="4" width="1080" height="1080" rx="120" fill="white"/> </clipPath> <clipPath id="clip1_2657_6950"> <rect width="424" height="125" fill="white" transform="translate(94 50)"/> </clipPath> </defs> </svg>';

        return string(abi.encodePacked(parts[0], parts[1], parts[2]));
    }

    /**
     * @notice Generates a JSON string containing the attributes for a given token ID.
     * @param tokenId The token ID to be used for generating the attributes.
     * @return string memory The generated JSON string containing the attributes.
     * @dev This function generates a JSON string containing various attributes associated with the token ID.
     * The attributes include tokenId, name, resolvedAddress, and expiresAt.
     */
    function generateAttributes(
        uint256 tokenId
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '[{"trait_type": "tokenId", "value": "',
                    tokenId.toString(),
                    '"}, {"trait_type": "name", "value": "',
                    getDisplayName(tokenId),
                    '"}, {"trait_type": "resolvedAddress", "value": "',
                    tokenData[tokenId].resolveAddress.toHexString(),
                    '"}, {"trait_type": "expiresAt", "value": "',
                    LibString.toString(nameExpires(tokenId)),
                    '"}]'
                )
            );
    }

    /**
     * @notice Generates a JSON string containing metadata for a given token ID.
     * @param tokenId The token ID to be used for generating the metadata.
     * @return string memory The generated JSON string containing the metadata.
     * @dev This function generates a JSON string containing metadata associated with the token ID.
     * The metadata includes the name, description, image (as a base64-encoded SVG), and attributes.
     */
    function generateJSON(
        uint256 tokenId
    ) internal view returns (string memory) {
        string
            memory description = unicode"Username NFTs are non-fungible tokens that represent usernames on the Linea zkRollup.";

        string memory attributes = generateAttributes(tokenId);

        return
            string(
                abi.encodePacked(
                    '{"name": ".linea Username NFTs',
                    getDisplayName(tokenId),
                    '", "description": "',
                    description,
                    '", "image": "data:image/svg+xml;base64,',
                    Base64.encode(bytes(generateSVG(tokenId))),
                    '", "attributes": ',
                    attributes,
                    "}"
                )
            );
    }

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
    ) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert InvalidTokenError();
        }

        string memory json = Base64.encode(bytes(generateJSON(tokenId)));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
