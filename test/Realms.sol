// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REALMS is ERC721 {
    uint256 private _nextTokenId;

    constructor()ERC721("REALMS", "RMS"){}

    function mint(address to) public {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }
}