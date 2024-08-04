// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

error NotEscrowedError();

/**
   @title Contract responsible of escrowing tokens.
*/
contract BridgeEscrow {

    // Escrowed token.
    mapping(uint256 => bool) _escrowed;

    /**
       @notice Deposits the given tokens into escrow.

       @param collection Token collection address.
       @param ids Tokens to be deposited.
     */
    function _depositIntoEscrow(address collection, uint256[] memory ids) internal {
        
        assert(ids.length > 0);

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            IERC721(collection).transferFrom(msg.sender, address(this), id);
            _escrowed[id] = true;
        }
    }

    /**
       @notice Withdraw tokens from escrow.

       @param collection Token collection address.
       @param to Recipient of the token.
       @param ids Token ids to be deposited.
     */
    function _withdrawFromEscrow(
        address collection,
        address to,
        uint256[] memory ids
    )
        internal
    {

        for (uint256 i = 0; i < ids.length; i++) {   
            uint256 id = ids[i];
            if (!_escrowed[id]) {revert NotEscrowedError();}

            IERC721(collection).safeTransferFrom(address(this), to, id);
            _escrowed[id] = false;
        }
    }
}
