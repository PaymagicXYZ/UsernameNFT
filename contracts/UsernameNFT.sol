pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UsernameController.sol";

/**
 * @title UsernameNFT
 * @dev UsernameNFT contract represents the NFTs for usernames.
 */
contract UsernameNFT is ERC721, Ownable {
    constructor() ERC721("Blank", "BLNK") {}

    uint256 public totalSupply;

    UsernameController public controller;

    struct TokenData {
        address owner;
        uint96 mintTimestamp;
        uint96 duration;
    }

    mapping(uint256 => TokenData) public tokenData;
    mapping(string => uint256) public nameToTokenId;
    mapping(address => string) public addressToName;

    event NameRegistered(address indexed owner, string name, uint256 tokenId);
    event NameRenewed(address indexed owner, string name, uint256 tokenId);

    modifier onlyController() {
        require(
            msg.sender == address(controller),
            "Only controller can call this function"
        );
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
        string memory name,
        uint96 duration
    ) external onlyController returns (uint256) {
        require(nameToTokenId[name] == 0, "Name already registered");
        uint256 tokenId = totalSupply++;
        _safeMint(to, tokenId);
        tokenData[tokenId] = TokenData({
            owner: to,
            mintTimestamp: uint96(block.timestamp),
            duration: duration
        });
        nameToTokenId[name] = tokenId;
        addressToName[to] = name;
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
        emit NameRenewed(data.owner, addressToName[data.owner], tokenId);
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
     * @notice Returns the owner address for a given username.
     * @param name The username to be resolved.
     * @return address The owner address of the username.
     */
    function resolveName(string memory name) external view returns (address) {
        uint256 tokenId = nameToTokenId[name];
        require(tokenId != 0, "Name not registered");
        TokenData memory data = tokenData[tokenId];
        if (block.timestamp > data.mintTimestamp + data.duration) {
            return address(0);
        }
        return data.owner;
    }

    /**
     * @notice Returns the username for a given owner address.
     * @param addr The owner address to be resolved.
     * @return string memory The username associated with the owner address.
     */
    function resolveAddress(
        address addr
    ) external view returns (string memory) {
        string memory name = addressToName[addr];
        require(bytes(name).length != 0, "Address not registered");
        uint256 tokenId = nameToTokenId[name];
        TokenData memory data = tokenData[tokenId];
        if (block.timestamp > data.mintTimestamp + data.duration) {
            return "";
        }
        return name;
    }

    /**
     * TO-DO: Implement this function
     * @notice Returns the URI for a given NFT.
     * @param tokenId The token ID of the NFT.
     * @return string memory The URI of the NFT.
     */
    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        //convert tokenId to string
        return Strings.toString(tokenId);
    }
}
