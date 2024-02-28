// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Votes.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Wrapper.sol";

contract RealmsLordShip is ERC721, EIP712, ERC721Votes, ERC721Wrapper {
    constructor() ERC721("MyToken", "MTK") EIP712("MyToken", "1") ERC721Wrapper("0x0") {}

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Votes)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Votes)
    {
        super._increaseBalance(account, value);
    }
}