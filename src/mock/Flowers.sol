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

contract FlowersMock is ERC721Enumerable, Ownable, ReentrancyGuard {
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

    uint64 private immutable MAX_SUPPLY;
    uint64 private immutable MAX_PER_TX = 15;
    uint64 constant internal SCALE = 10000;
    uint64 constant internal FEE = 600;

    uint256 private immutable startSaleTimestamp;

    address private immutable ruggedBees;
    address private immutable crobees;
    address private immutable honeyToken;
    address private immutable moonflow;
    address private immutable feesAddress = 0xFbfF4df52bD43D7AbC1fD9c5a9A29b856c4866c5;

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

    constructor(
        string memory _baseURI, 
        address _ruggedBees, 
        address _crobees, 
        address _honeyToken,
        address _moonflow,
        uint256 _startSaleTimestamp,
        uint64 _maxSupply
    ) ERC721("Flowers", "FLOW") {
        setBaseURI(_baseURI);
        ruggedBees = _ruggedBees;
        crobees = _crobees;
        honeyToken = _honeyToken;
        moonflow = _moonflow;
        startSaleTimestamp = _startSaleTimestamp;

        mintTypes[MintType.ETH] = Mint(30, 30, 75 ether);
        mintTypes[MintType.HONEY] = Mint(20, 20, 250 ether);
        mintTypes[MintType.AIRDROP] = Mint(10, 10, 0);
        MAX_SUPPLY = _maxSupply;
    }

    /*//////////////////////////////////////////////////////////////
                               MINT LOGIC
    //////////////////////////////////////////////////////////////*/

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
            return 25 ether;
        } else if (IERC721(moonflow).balanceOf(_minter) > 0) {
            return 50 ether;
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

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
