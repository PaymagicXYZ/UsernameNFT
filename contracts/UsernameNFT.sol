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
        ] = '<svg width="1080" height="1080" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg"> <g clip-path="url(#clip0_3440_100626)"> <rect width="1080" height="1080" rx="120" fill="#2B3A14"/> <path d="M279 -31L-18 266H1124.5L256 1134.5" stroke="#394C1A" stroke-width="29"/> <path d="M277 262L-18 557H1124.5L256 1425.5" stroke="#394C1A" stroke-width="29"/> <rect x="-45" y="749" width="1159" height="237" fill="#3E531C"/> <text fill="#ADE64F" xml:space="preserve" style="white-space: pre" font-family="Arial" font-size="96" letter-spacing="-0.04em"><tspan x="63" y="899.281">';
        parts[1] = getDisplayName(tokenId);
        parts[
            2
        ] = '</tspan></text> <g clip-path="url(#clip1_3440_100626)"> <mask id="mask0_3440_100626" style="mask-type:luminance" maskUnits="userSpaceOnUse" x="84" y="92" width="429" height="150"> <path d="M512.182 92H84V242H512.182V92Z" fill="white"/> </mask> <g mask="url(#mask0_3440_100626)"> <path d="M187.986 137.156C188.175 132.616 187.495 128.177 185.962 123.956C183.009 115.826 177.175 109.387 169.534 105.823C153.19 98.2024 133.385 105.96 125.385 123.115L98.4082 180.968C94.3406 190.67 93.9639 200.234 97.3178 208.624C100.314 216.118 106.106 222.176 113.623 225.682C121.14 229.187 129.512 229.733 137.183 227.21C145.768 224.388 152.853 217.951 157.664 208.599L157.676 208.572L157.689 208.545L184.641 150.747C186.661 146.429 187.785 141.855 187.982 137.158L187.986 137.156Z" fill="#B4DC00"/> <path d="M125.503 133.685C125.484 147.978 136.358 169.053 150.058 174.515C165.169 179.361 172.509 160.374 179.739 150.625C171.085 169.183 162.431 187.748 153.758 206.297C146.205 222.6 123.589 229.448 109.881 216.752C125.746 227.264 145.174 213.703 148.089 196.68C150.025 187.948 139.164 182.824 134.532 176.716C125.967 167.519 117.625 152.01 122.782 139.429C123.843 137.605 124.608 135.606 125.503 133.685ZM182.982 130.644C183.656 138.78 178.606 145.544 172.687 150.523C167.087 156.094 158.337 157.648 153.844 149.939C149.611 143.103 149.854 134.833 150.595 127.137C151.699 118.225 142.655 113.337 138.269 114.192C136.202 114.595 133.252 118.222 132.238 120.066C131.468 121.464 130.486 124.196 131.736 126.427C134.402 130.276 135.743 134.698 137.313 139.031C142.881 157.431 154.552 176.134 172.456 155.809C178.66 148.929 185.21 140.47 183.234 130.624L182.986 130.642L182.982 130.644ZM101.607 202.106C105.062 213.483 119.07 219.828 129.132 212.474C136.218 208.069 137.923 198.293 133.525 191.394C124.892 178.475 115.788 167.785 117.472 151.055C115.765 154.125 114.477 157.437 112.928 160.604C111.988 169.804 115.124 179.17 119.175 187.36C121.59 192.776 125.497 198.007 124.94 204.225C124.337 210.146 117.873 213.074 112.51 211.664C107.459 210.527 104.094 206.416 101.848 202.018C101.766 202.045 101.687 202.074 101.605 202.102L101.607 202.106ZM147.652 108.897C161.632 110.725 161.034 123.49 160.68 134.514C160.552 139.569 163.617 146.806 169.791 145.273C181.397 142.404 185.631 127.408 177.928 118.502C180.265 123.592 181.543 128.734 177.895 133.642C176.068 136.673 171.082 137.186 169.838 133.456C166.939 125.423 167.484 115.215 159.835 109.716C156.451 106.253 151.817 107.906 147.639 108.631C147.642 108.722 147.65 108.811 147.654 108.901L147.652 108.897ZM104.591 178.814C101.721 184.552 101.144 191.615 104.233 197.398C109.205 206.227 117.374 202.994 113.42 192.996C111.509 187.063 109.701 181.105 108.319 175.024C107.175 172.405 105.135 177.879 104.488 178.76C104.523 178.776 104.561 178.794 104.596 178.81L104.591 178.814Z" fill="#006400"/> <path d="M257.902 196.39L254.601 189.915C252.189 193.406 248.443 196.517 241.46 196.517C228.89 196.517 220.32 186.613 220.32 173.599C220.32 158.681 230.414 148.65 242.92 148.65C246.92 148.65 249.396 149.222 252.951 152.015L255.554 148.841H257.648L260.315 166.553L258.093 166.807C254.411 157.665 250.411 151.38 243.047 151.38C235.747 151.38 231.112 159.062 231.112 173.282C231.112 188.962 235.747 193.47 242.159 193.47C248.189 193.47 251.237 188.899 251.237 182.677V180.011C251.237 178.678 250.665 177.599 248.951 177.535L243.873 177.345V174.361H264.378V177.345L259.68 177.599V179.503C259.68 185.534 259.807 189.661 260.251 196.39H257.902Z" fill="#B4DC00"/> <path d="M267.667 195.376V192.773L272.174 192.519V173.347C272.174 171.315 271.476 170.426 268.747 170.426H266.334V167.824C269.889 167.76 273.19 166.3 275.666 164.713H278.65L278.967 174.807L279.285 174.87C281.189 168.077 284.49 164.459 289.188 164.459C292.489 164.459 294.521 167.379 294.521 170.109C294.521 173.029 292.68 175.632 290.077 175.632C287.538 175.632 285.887 173.537 285.887 171.379C285.887 169.474 286.966 168.966 286.966 168.331C286.966 168.141 286.776 168.014 286.585 168.014C283.348 168.014 279.602 177.727 279.602 185.917V190.36C279.602 192.011 280.3 192.519 281.761 192.582L287.093 192.773V195.376H267.667Z" fill="#B4DC00"/> <path d="M298.521 180.711C298.521 171.125 305.759 164.332 313.694 164.332C322.709 164.332 327.343 171.061 327.343 178.489L307.663 182.171C307.663 187.376 309.187 192.836 315.98 192.836C319.852 192.836 323.471 190.233 325.248 185.345L327.47 186.361C325.946 191.376 320.804 196.518 314.012 196.518C305.06 196.518 298.521 190.17 298.521 180.711ZM317.249 177.727C318.519 177.473 319.281 176.775 319.281 175.632C319.281 171.315 318.329 166.808 314.202 166.808C308.996 166.808 307.663 172.648 307.663 179.504L317.249 177.727Z" fill="#B4DC00"/> <path d="M332.172 180.711C332.172 171.125 339.409 164.332 347.345 164.332C356.359 164.332 360.993 171.061 360.993 178.489L341.313 182.171C341.313 187.376 342.837 192.836 349.63 192.836C353.502 192.836 357.121 190.233 358.899 185.345L361.122 186.361C359.597 191.376 354.454 196.518 347.662 196.518C338.711 196.518 332.172 190.17 332.172 180.711ZM350.9 177.727C352.169 177.473 352.931 176.775 352.931 175.632C352.931 171.315 351.979 166.808 347.852 166.808C342.647 166.808 341.313 172.648 341.313 179.504L350.9 177.727Z" fill="#B4DC00"/> <path d="M386.069 195.372V192.769L389.497 192.515V177.406C389.497 173.089 388.101 170.042 384.228 170.042C380.672 170.042 378.386 173.406 378.386 179.056V190.61C378.386 192.261 378.896 192.515 380.355 192.578L383.593 192.769V195.372H366.58V192.769L370.262 192.515V173.343C370.262 171.311 369.564 170.423 366.834 170.423H364.42V167.82C367.976 167.756 372.61 166.296 375.086 164.709H378.007L378.261 171.629C380.737 166.74 384.61 164.709 388.417 164.709C394.259 164.709 397.559 168.708 397.559 175.311V190.483C397.559 191.943 397.941 192.515 399.528 192.578L403.21 192.769V195.372H386.069Z" fill="#B4DC00"/> <path d="M406.852 195.374V192.39L412.629 192.136V154.872C412.629 153.538 411.93 152.777 410.916 152.713L405.137 152.523V149.539H428.88C438.911 149.539 447.036 152.967 447.036 162.68C447.036 171.314 440.436 175.948 428.31 175.948C426.469 175.948 423.739 175.884 422.087 175.758V189.914C422.087 191.565 423.041 192.136 424.438 192.2L430.277 192.39V195.374H406.852ZM436.751 162.426C436.751 153.03 431.229 152.269 426.15 152.269L422.087 152.332V172.774H425.706C432.69 172.774 436.751 171.504 436.751 162.426Z" fill="#B4DC00"/> <path d="M454.387 154.048C454.387 151.127 456.545 148.842 459.34 148.842C462.133 148.842 464.418 151.127 464.418 154.048C464.418 156.904 462.133 159.19 459.34 159.19C456.545 159.19 454.387 156.904 454.387 154.048ZM451.657 195.375V192.772L455.656 192.519V173.347C455.656 171.315 454.957 170.426 452.227 170.426H449.816V167.823C453.37 167.76 458.006 166.3 460.483 164.713H463.783V190.614C463.783 192.265 464.29 192.519 465.752 192.582L469.813 192.772V195.375H451.657Z" fill="#B4DC00"/> <path d="M472.901 195.374V192.772L476.965 192.518V157.411C476.965 155.38 476.267 154.491 473.537 154.491H471.123V151.888C474.679 151.825 479.313 150.365 481.789 148.777H484.898V190.55C484.898 192.2 485.408 192.518 486.868 192.581L491.057 192.772V195.374H472.901Z" fill="#B4DC00"/> <path d="M494.022 195.374V192.772L498.086 192.518V157.411C498.086 155.38 497.388 154.491 494.658 154.491H492.244V151.888C495.801 151.825 500.434 150.365 502.911 148.777H506.022V190.55C506.022 192.2 506.53 192.518 507.989 192.581L512.18 192.772V195.374H494.022Z" fill="#B4DC00"/> </g> </g> </g> <defs> <clipPath id="clip0_3440_100626"> <rect width="1080" height="1080" rx="120" fill="white"/> </clipPath> <clipPath id="clip1_3440_100626"> <rect width="429" height="150" fill="white" transform="translate(84 92)"/> </clipPath> </defs> </svg>';

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
            memory description = unicode"Username NFTs are non-fungible tokens that represent usernames in the Regen community.";

        string memory attributes = generateAttributes(tokenId);

        return
            string(
                abi.encodePacked(
                    '{"name": ".regen Username NFTs ',
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
