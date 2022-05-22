// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns ERC-721 token

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { ERC721Checkpointable } from './base/ERC721Checkpointable.sol';
import { INounsDescriptor } from './interfaces/INounsDescriptor.sol';
import { INounsSeeder } from './interfaces/INounsSeeder.sol';
import { INounsToken } from './interfaces/INounsToken.sol';
import { ERC721 } from './base/ERC721.sol';
import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { IProxyRegistry } from './external/opensea/IProxyRegistry.sol';
import "@openzeppelin/contracts/utils/Strings.sol";


contract NounsToken is INounsToken, Ownable, ERC721Checkpointable {
    // An address who has permissions to mint Nouns
    address public minter;

    // The Nouns token URI descriptor
    INounsDescriptor public descriptor;

    // The Nouns token seeder
    INounsSeeder public seeder;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // Whether the descriptor can be updated
    bool public isDescriptorLocked;

    // Whether the seeder can be updated
    bool public isSeederLocked;

    // The noun seeds
    mapping(uint256 => INounsSeeder.Seed) public seeds;

    // The internal noun ID tracker
    uint256 private _currentNounId;

    uint256 public mintTime;
    uint256 public testTime;
    
    struct PriceSeed {
        uint256 maxPrice;
        uint256 minPrice;
        uint256 priceDelta;
        uint256 timeDelta;
        uint256 expirationTime;
    }
    PriceSeed public priceSeed;
    
    address[] public developpers;
    
    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    /**
     * @notice Require that the minter has not been locked.
     */
    modifier whenMinterNotLocked() {
        require(!isMinterLocked, 'Minter is locked');
        _;
    }

    /**
     * @notice Require that the descriptor has not been locked.
     */
    modifier whenDescriptorNotLocked() {
        require(!isDescriptorLocked, 'Descriptor is locked');
        _;
    }

    /**
     * @notice Require that the seeder has not been locked.
     */
    modifier whenSeederNotLocked() {
        require(!isSeederLocked, 'Seeder is locked');
        _;
    }

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, 'Sender is not the minter');
        _;
    }

    constructor(
        address _minter,
        INounsDescriptor _descriptor,
        INounsSeeder _seeder,
        address[] memory _developpers,
        PriceSeed memory _priceSeed,
        IProxyRegistry _proxyRegistry
    ) ERC721('Nouns love', 'NOUN') {
        minter = _minter;
        descriptor = _descriptor;
        seeder = _seeder;
        developpers = _developpers;
        proxyRegistry = _proxyRegistry;

        priceSeed.maxPrice = _priceSeed.maxPrice;
        priceSeed.minPrice = _priceSeed.minPrice;
        priceSeed.priceDelta = _priceSeed.priceDelta;
        priceSeed.timeDelta = _priceSeed.timeDelta;
        priceSeed.expirationTime = _priceSeed.expirationTime;
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice Mint a Noun to the minter, along with a possible nounders reward
     * Noun. Nounders reward Nouns are minted every 10 Nouns, starting at 0,
     * until 183 nounder Nouns have been minted (5 years w/ 24 hour auctions).
     * @dev Call _mintTo with the to address(es).
     */
    function mint() public override onlyMinter returns (uint256) {
        require(_currentNounId == 0, 'First mint only'); 
        _mintTo(minter, _currentNounId++);
        setMintTime();
        return _mintTo(address(this), _currentNounId++);
    }
    /*
      @ 
     */
    function buy(uint256 tokenId) external payable returns (uint256) {
        address from = ownerOf(tokenId);
        address to = msg.sender;
        uint256 currentPrice = price();
        require(from == address(this), 'Owner is not the contract');
        require(tokenId == (_currentNounId - 1), 'Not latest Noun');
        require(msg.value >= currentPrice, 'Must send at least currentPrice');
        
        buyTransfer(to, tokenId);
        
        if (_currentNounId % 10 == 0) {
            uint256 devIndex = (_currentNounId / 10) % developpers.length;
            address developper = developpers[devIndex];
            // TODO developpers
            _mintTo(developper, _currentNounId++);
        }
        emit NounBought(tokenId, to);
        setMintTime();
        return _mintTo(address(this), _currentNounId++);
    }
    function getCurrentToken() public view returns (uint256) {                  
        return _currentNounId;
    }
    function getMintTime() public view returns (uint256) {                  
        return mintTime;
    }
    function setMintTime() private {
        mintTime = block.timestamp;
        emit MintTimeUpdated(mintTime);
    }
    /*
     * maxPrice - (time diff / time step) * price step
     */
    function price() public view returns (uint256) {
        uint256 timeDiff = block.timestamp - mintTime;
        if (timeDiff < priceSeed.timeDelta ) {
            return priceSeed.maxPrice;
        }
        uint256 priceDiff = uint256(timeDiff / priceSeed.timeDelta) * priceSeed.priceDelta;
        if (priceDiff >= priceSeed.maxPrice - priceSeed.minPrice) {
            return priceSeed.minPrice;
        }
        return priceSeed.maxPrice - priceDiff;
    }
    function burnExpireToken() public {
        uint256 timeDiff = block.timestamp - mintTime;
        if (timeDiff > priceSeed.expirationTime) {
            burn(_currentNounId - 1);
        }
        setMintTime();
        _mintTo(address(this), _currentNounId++);
    }
    
    /**
     * @notice Burn a noun.
     */
    function burn(uint256 nounId) public override onlyMinter {
        _burn(nounId);
        emit NounBurned(nounId);
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'NounsToken: URI query for nonexistent token');
        return descriptor.tokenURI(tokenId, seeds[tokenId]);
    }

    /**
     * @notice Similar to `tokenURI`, but always serves a base64 encoded data URI
     * with the JSON contents directly inlined.
     */
    function dataURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'NounsToken: URI query for nonexistent token');
        return descriptor.dataURI(tokenId, seeds[tokenId]);
    }

    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */
    function setMinter(address _minter) external override onlyOwner whenMinterNotLocked {
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    /**
     * @notice Lock the minter.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;

        emit MinterLocked();
    }

    /**
     * @notice Set the token URI descriptor.
     * @dev Only callable by the owner when not locked.
     */
    function setDescriptor(INounsDescriptor _descriptor) external override onlyOwner whenDescriptorNotLocked {
        descriptor = _descriptor;

        emit DescriptorUpdated(_descriptor);
    }

    /**
     * @notice Lock the descriptor.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockDescriptor() external override onlyOwner whenDescriptorNotLocked {
        isDescriptorLocked = true;

        emit DescriptorLocked();
    }

    /**
     * @notice Set the token seeder.
     * @dev Only callable by the owner when not locked.
     */
    function setSeeder(INounsSeeder _seeder) external override onlyOwner whenSeederNotLocked {
        seeder = _seeder;

        emit SeederUpdated(_seeder);
    }

    /**
     * @notice Lock the seeder.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockSeeder() external override onlyOwner whenSeederNotLocked {
        isSeederLocked = true;

        emit SeederLocked();
    }

    /**
     * @notice Mint a Noun with `nounId` to the provided `to` address.
     */
    function _mintTo(address to, uint256 nounId) internal returns (uint256) {
        INounsSeeder.Seed memory seed = seeds[nounId] = seeder.generateSeed(nounId, descriptor);

        _mint(owner(), to, nounId);
        emit NounCreated(nounId, seed);

        return nounId;
    }

    function transfer() external onlyOwner {
        address payable payableTo = payable(minter);
        payableTo.transfer(address(this).balance);
    }

    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */

    function setPriceData(PriceSeed memory _priceSeed) external onlyOwner {
        priceSeed.maxPrice = _priceSeed.maxPrice;
        priceSeed.minPrice = _priceSeed.minPrice;
        priceSeed.priceDelta = _priceSeed.priceDelta;
        priceSeed.timeDelta = _priceSeed.timeDelta;
        priceSeed.expirationTime = _priceSeed.expirationTime;
    }
    function getPriceData() public view returns (PriceSeed memory) {
        return priceSeed;
    }

    
    function addDevelopper(address _developper) external onlyOwner {
        developpers.push(_developper);
    }
}
