//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "src/token/IERC20Burnable.sol";

interface IERC1155 {
    function balanceOf(address account, uint id) external view returns (uint256);
}

contract Flowers is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    enum MintType { ETH, HONEY, AIRDROP }

    struct Mint {
        uint64 supplyRemaining;
        uint64 totalSupply;
        uint128 price;
    }

    string public baseURI;

    uint public counter;
    bool public freeze;

    uint64 private immutable MAX_SUPPLY = 1500;
    uint64 private immutable MAX_PER_TX = 15;
    uint64 constant internal SCALE = 10000;
    uint64 constant internal FEE = 600;

    uint256 private immutable startSaleTimestamp = 1676487600;

    address private immutable ruggedBees = 0x15Ee1dF8A9888b68b7Fa8D2b8202997C115FEBf2;
    address private immutable crobees = 0xAed630F0B36DcbBa21Bdbe99F8662f13CC4FaFB1;
    address private immutable moonflow = 0xEFA293ecD55e378aa614710C2Aee81886B3F84e0;
    address private immutable feesAddress = 0xFbfF4df52bD43D7AbC1fD9c5a9A29b856c4866c5;
    address private honeyToken;

    mapping(MintType => Mint) public mintTypes;

    event flowerMinted(address indexed _minter, uint[] _tokenIDs);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isOpen(uint256 _count) {
        require(block.timestamp >= startSaleTimestamp, "SALE IS NOT OPEN");
        require(_count > 0, 'CAN NOT MINT 0 NFT');
        require(_count <= MAX_PER_TX, 'MAX PER TX IS 15');
        _;
    }

    modifier isNotFreeze {
        require(!freeze, "ERROR: MINT IS FROZEN");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/    

    constructor(string memory _baseURI, address _honey) ERC721("Flowers", "FLOW") {
        setBaseURI(_baseURI);
        honeyToken = _honey;
        mintTypes[MintType.ETH] = Mint(600, 600, 200 ether);
        mintTypes[MintType.HONEY] = Mint(500, 500, 250 ether);
        mintTypes[MintType.AIRDROP] = Mint(400, 400, 0);
    }

    /*//////////////////////////////////////////////////////////////
                               MINT LOGIC
    //////////////////////////////////////////////////////////////*/
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function freezeMint() external onlyOwner {
        freeze = !freeze;
    }

    function airdrop(address[] calldata _to) external onlyOwner {
        require(
            totalSupply() >=  mintTypes[MintType.ETH].totalSupply + mintTypes[MintType.HONEY].totalSupply, 
            "ERROR: ETH MINT NOT FINISHED"
        );
        require(totalSupply() + _to.length <= MAX_SUPPLY, "MAX SUPPLY REACHED");
        uint currentCounter = counter;
        for(uint i = 0; i < _to.length; i++){
            currentCounter++;
            _safeMint(_to[i], currentCounter);
        }
        counter = currentCounter;
    }

    function _ethMint(uint _amount) private  {
        uint[] memory tokenIdsBought = new uint[](_amount);
        uint currentCounter = counter;

        uint totalCost = _cost(msg.sender) * _amount;
        require(msg.value >= totalCost, "ERROR: NOT ENOUGH ETH");
        uint mintFee = totalCost * FEE / SCALE;
        payable(feesAddress).transfer(mintFee);

        uint64 currentSupplyRemaining = mintTypes[MintType.ETH].supplyRemaining;
        require(currentSupplyRemaining >= _amount, "ERROR: NOT ENOUGH SUPPLY");
       
        for(uint i = 0; i < _amount; i++){
            currentCounter++;
            currentSupplyRemaining--;
            tokenIdsBought[i] = currentCounter;
            _mint(msg.sender, currentCounter);
        }

        mintTypes[MintType.ETH].supplyRemaining = currentSupplyRemaining;
        counter = currentCounter;
        emit flowerMinted(msg.sender, tokenIdsBought);

    }

    function _honeyMint(uint _amount) private {
        uint[] memory tokenIdsBought = new uint[](_amount);
        uint currentCounter = counter;
        uint64 currentSupplyRemaining = mintTypes[MintType.HONEY].supplyRemaining;
        uint totalCost = mintTypes[MintType.HONEY].price * _amount;
        require(currentSupplyRemaining >= _amount, "ERROR: NOT ENOUGH SUPPLY");
        require(IERC20Burnable(honeyToken).balanceOf(msg.sender) >= totalCost, "ERROR: NOT ENOUGH HONEY");
        IERC20Burnable(honeyToken).burnFrom(msg.sender, totalCost);
       
        for(uint i = 0; i < _amount; i++){
            currentCounter++;
            currentSupplyRemaining--;
            tokenIdsBought[i] = currentCounter;
            _mint(msg.sender, currentCounter);
        }

        mintTypes[MintType.HONEY].supplyRemaining = currentSupplyRemaining;
        counter = currentCounter;
        emit flowerMinted(msg.sender, tokenIdsBought);
    }

    function mintCost(address _minter) external view returns (uint256) {
        return _cost(_minter);
    }

    function _cost(address _minter) internal view returns (uint256) {
        if (mintTypes[MintType.ETH].supplyRemaining == 0 ) return mintTypes[MintType.HONEY].price;
        if(IERC1155(ruggedBees).balanceOf(_minter, 1) > 0 || IERC721(crobees).balanceOf(_minter) > 0) {
            return 150 ether;
        } else if (IERC721(moonflow).balanceOf(_minter) > 0) {
            return 175 ether;
        } else {
            return mintTypes[MintType.ETH].price;
        }
    }

    function canMint() external view returns (uint256) {
        if(block.timestamp >= startSaleTimestamp) {
            if (mintTypes[MintType.ETH].supplyRemaining > 0) {
                if (mintTypes[MintType.ETH].supplyRemaining < MAX_PER_TX) {
                    return mintTypes[MintType.ETH].supplyRemaining;
                }
                return MAX_PER_TX;
            }
            if (mintTypes[MintType.HONEY].supplyRemaining > 0) {
                if (mintTypes[MintType.HONEY].supplyRemaining < MAX_PER_TX) {
                    return mintTypes[MintType.HONEY].supplyRemaining;
                }
                return MAX_PER_TX;
            }
            return 0;
        }
        return 0;
    }

    function mint(uint256 _amount) external payable isOpen(_amount) isNotFreeze nonReentrant {
        uint currentSupply = counter;
        uint mintSupply = mintTypes[MintType.ETH].totalSupply + mintTypes[MintType.HONEY].totalSupply;
        require(currentSupply + _amount <= mintSupply, "ERROR: MINT IS OVER");
        if(mintTypes[MintType.ETH].supplyRemaining > 0) {
            _ethMint(_amount);
        } else {
            _honeyMint(_amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/ 
    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
      require(_exists(_tokenId),"ERC721Metadata: URI query for nonexistent token");
      string memory _tokenURI = string(abi.encodePacked(baseURI, Strings.toString(_tokenId),".json"));
      return _tokenURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setHoneyToken(address _newAddress) external onlyOwner {
        honeyToken = _newAddress;
    }
}