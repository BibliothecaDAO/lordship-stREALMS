// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Votes.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Wrapper.sol";

contract RealmsLordShip is ERC721, EIP712, ERC721Votes, ERC721Wrapper {

    // using SuperTokenV1Library for ISuperToken;

    // ISuperToken private _superToken;

    constructor(address superLords) ERC721("MyToken", "MTK") EIP712("MyToken", "1") ERC721Wrapper("0x0") {
        // _superToken = ISuperToken(SuperLords);
    }

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

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
        public
        virtual
        override(ERC721Wrapper)
        returns (bytes4)
    {
        // here we initalise a Lords Stream via superfluid
        // each token increases flow rate
        // on new token received, we increase flow rate

        // when balance is decreased, we decrease flow rate
        return super.onERC721Received(operator, from, tokenId, data);
    }
}