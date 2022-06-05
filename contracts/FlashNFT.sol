// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FlashNFT is ERC721, ERC721Enumerable, ERC721Burnable, Ownable, EIP712, ERC721Votes {
    using Strings for uint256;
    using Counters for Counters.Counter;
    string public baseURI;
    string _baseExtension = ".jpg";
    uint public maxSupply = 5000;
    mapping(address => bool) validTargets;
    Counters.Counter private _tokenIdCounter;

    constructor(string memory _baseURI)
        ERC721("Minh Dang Token", "MDT")
        EIP712("Minh Dang Token", "1")
    {
        baseURI = _baseURI;
    }

    function setValidTarget(address _target, bool _permission) public onlyOwner{
        validTargets[_target] = _permission;
    }

    function setBaseExtension(string memory baseExtension_) public onlyOwner {
        _baseExtension = baseExtension_;
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        baseURI = _uri;
    }

    function mintValidTarget(uint _amount) public{
        require (validTargets[_msgSender()], "FlashNFT: Not valid target!");
        require (_tokenIdCounter.current() + _amount <= maxSupply, "FlashNFT: Overallowance supply!");
        for (uint i = 0; i < _amount; i++){
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_msgSender(), tokenId);
        }
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Votes)
    {
        super._afterTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "FlashNFT: Not owner or approved by owner"
        );
        super._burn(tokenId);
    }

    function _mint(address to, uint tokenId) internal override(ERC721){
        require(totalSupply() < maxSupply, "FlashNFT: Overallowance supply!");
        super._mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, tokenId.toString(), _baseExtension));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}