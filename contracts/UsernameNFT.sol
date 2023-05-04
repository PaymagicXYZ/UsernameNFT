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
     * @param tokenId The token ID of the NFT to be updated.
     * @dev This function can only be called by resolved address of the NFT. It updates the primary name
     * for the given tokenId with the provided newResolvedAddress. It also updates the primary name
     * for the old and new resolved addresses if needed.
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
    ) internal pure returns (string memory) {
        string[3] memory parts;

        parts[
            0
        ] = '<svg width="1080" height="1080" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg"> <g clip-path="url(#clip0_2657_6961)"> <rect width="1080" height="1080" rx="120" fill="#131315"/> <path d="M279 -31L-18 266H1124.5L256 1134.5" stroke="#231032" stroke-width="29"/> <path d="M277 262L-18 557H1124.5L256 1425.5" stroke="#231032" stroke-width="29"/> <rect x="-45" y="749" width="1159" height="237" fill="#321747"/> <text fill="#8E34D5" xml:space="preserve" style="white-space: pre" font-family="Arial" font-size="96" letter-spacing="-0.04em"><tspan x="63" y="899.281">';
        parts[1] = tokenId.toString();
        parts[
            2
        ] = '</tspan></text> <g clip-path="url(#clip1_2657_6961)"> <path d="M176.396 167.367L205.797 150.901C207.356 150.027 208.319 148.405 208.319 146.664V113.731C208.319 111.991 207.356 110.369 205.797 109.494L176.396 93.0278C174.838 92.1531 172.903 92.1616 171.353 93.0278L141.952 109.494C140.394 110.369 139.431 111.991 139.431 113.731V172.581L118.812 184.122L98.1925 172.581V149.492L118.812 137.951L132.409 145.568V130.079L121.333 123.871C120.571 123.446 119.696 123.217 118.812 123.217C117.927 123.217 117.052 123.446 116.29 123.871L86.8892 140.337C85.3308 141.212 84.3677 142.834 84.3677 144.575V177.507C84.3677 179.248 85.3308 180.87 86.8892 181.744L116.29 198.211C117.849 199.077 119.775 199.077 121.333 198.211L150.734 181.744C152.293 180.87 153.256 179.248 153.256 177.507V118.657L153.623 118.453L173.866 107.116L194.485 118.657V141.747L173.866 153.287L160.286 145.687V161.177L171.344 167.367C172.903 168.234 174.838 168.234 176.388 167.367H176.396Z" fill="url(#paint0_linear_2657_6961)"/> <path d="M240.723 184.613V117.492H251.019L252 122.91H252.49C255.432 119.199 260.431 116.541 267.392 116.541C280.131 116.541 290.331 126.621 290.331 141.542C290.331 156.462 280.14 166.542 267.392 166.542C260.528 166.542 255.73 163.782 253.182 160.649H252.691V184.605H240.731L240.723 184.613ZM278.362 141.55C278.362 132.803 272.575 127.292 265.518 127.292C258.461 127.292 252.674 132.803 252.674 141.55C252.674 150.297 258.461 155.808 265.518 155.808C272.575 155.808 278.362 150.297 278.362 141.55Z" fill="#F7F5F4"/> <path d="M296.398 141.542C296.398 126.995 307.176 116.541 321.588 116.541C335.999 116.541 346.777 126.995 346.777 141.542C346.777 156.089 335.999 166.542 321.588 166.542C307.176 166.542 296.398 155.987 296.398 141.542ZM334.721 141.542C334.721 132.982 328.837 127.283 321.588 127.283C314.338 127.283 308.358 132.99 308.358 141.542C308.358 150.093 314.338 155.706 321.588 155.706C328.837 155.706 334.721 150.102 334.721 141.542Z" fill="#F7F5F4"/> <path d="M355.437 165.601V99.0488H367.396V165.601H355.437Z" fill="#F7F5F4"/> <path d="M411.804 117.492H424.544L402.979 175.96C400.825 181.76 397.883 184.614 390.135 184.614H378.569V173.871H388.375C390.143 173.871 391.115 173.013 391.711 171.587L392.884 168.453L372.694 117.492H385.433L398.277 150.866H400.239L411.804 117.492Z" fill="#F7F5F4"/> <path d="M426.82 167.977H438.973C439.463 171.111 442.694 175.391 450.346 175.391C457.499 175.391 462.21 171.018 462.21 164.36V157.609H461.719C459.075 160.369 454.172 162.84 447.894 162.84C435.155 162.84 425.349 153.329 425.349 139.639C425.349 125.95 435.155 116.541 447.894 116.541C454.461 116.541 459.268 119.106 462.306 122.723H462.796L463.777 117.492H474.17V164.36C474.17 177.098 465.344 185.565 450.346 185.565C433.588 185.565 427.118 174.915 426.82 167.977ZM462.21 139.648C462.21 132.141 456.72 126.91 449.759 126.91C442.799 126.91 437.405 132.141 437.405 139.648C437.405 147.155 442.895 152.479 449.759 152.479C456.624 152.479 462.21 147.248 462.21 139.648Z" fill="#F7F5F4"/> <path d="M482.487 141.542C482.487 126.995 493.265 116.541 507.677 116.541C522.088 116.541 532.866 126.995 532.866 141.542C532.866 156.089 522.088 166.542 507.677 166.542C493.265 166.542 482.487 155.987 482.487 141.542ZM520.81 141.542C520.81 132.982 514.926 127.283 507.677 127.283C500.427 127.283 494.447 132.99 494.447 141.542C494.447 150.093 500.427 155.706 507.677 155.706C514.926 155.706 520.81 150.102 520.81 141.542Z" fill="#F7F5F4"/> <path d="M541.192 165.6V117.492H551.48L552.461 122.052H552.951C554.912 119.87 559.815 116.541 567.257 116.541C578.631 116.541 586.861 124.524 586.861 136.693V165.591H574.901V138.213C574.901 132.031 570.392 127.564 564.219 127.564C558.047 127.564 553.144 132.226 553.144 138.213V165.591H541.184L541.192 165.6Z" fill="#F7F5F4"/> <path d="M644.352 165.167H609.328V160.723L637.004 123.791H609.805V118.885H643.875V123.328L616.199 160.261H644.352V165.167Z" fill="#F7F5F4"/> <path d="M660.18 165.167H654.836V100.373H660.18V140.268L683.848 118.886H690.91L665.811 141.564L691.865 165.167H684.802L660.18 142.86V165.167Z" fill="#F7F5F4"/> <path d="M742.411 165.167H700.42V100.373H742.411V105.649H706.146V129.808H740.502V135.084H706.146V159.891H742.411V165.167Z" fill="#F7F5F4"/> <path d="M783.056 165.167H773.799L749.654 100.373H755.762L777.425 159.336H779.429L801.188 100.373H807.201L783.056 165.167Z" fill="#F7F5F4"/> <path d="M822.644 165.167H816.918V100.373H827.893L850.32 158.966H852.229L874.656 100.373H885.631V165.167H879.905V107.5H877.996L855.855 165.167H846.598L824.553 107.5H822.644V165.167Z" fill="#F7F5F4"/> </g> </g> <defs> <linearGradient id="paint0_linear_2657_6961" x1="83.9649" y1="180.734" x2="201.135" y2="110.615" gradientUnits="userSpaceOnUse"> <stop stop-color="#A726C1"/> <stop offset="0.88" stop-color="#803BDF"/> <stop offset="1" stop-color="#7B3FE4"/> </linearGradient> <clipPath id="clip0_2657_6961"> <rect width="1080" height="1080" rx="120" fill="white"/> </clipPath> <clipPath id="clip1_2657_6961"> <rect width="802" height="107" fill="white" transform="translate(84 92)"/> </clipPath> </defs> </svg>';

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
            memory description = unicode"Username NFTs are non-fungible tokens that represent usernames on Polygon's zkEVM.";

        string memory attributes = generateAttributes(tokenId);

        return
            string(
                abi.encodePacked(
                    '{"name": ".zkevm Username ',
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
