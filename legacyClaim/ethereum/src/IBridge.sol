// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sn/Cairo.sol";

/**
 */
interface IBridge {
    /**
       @notice Deposits token in escrow and initiates the
       transfer to Starknet. Will revert if any of the token is missing approval
       for the bridge as operator.

       @param salt A salt used to generate the request hash.
       @param ownerL2 New owner address on Starknet.
       @param ids Ids of the token to transfer. At least 1 token is required.
    */
    function depositTokens(uint256 salt, snaddress ownerL2, uint256[] calldata ids)
        external
        payable;

    /**
       @notice Withdraw tokens received from L2.

       @param request Serialized request containing the tokens to be withdrawed. 
    */
    function withdrawTokens(uint256[] calldata request)
        external
        payable;

    /**
        @notice Start the cancellation of a given request.
     
        @param payload Request to cancel
        @param nonce Nonce used for request sending.
     */
    function startRequestCancellation(
        uint256[] memory payload,
        uint256 nonce
    ) external;

    /**
        @notice Cancel a given request.

        @param payload Request to cancel
        @param nonce Nonce used for request sending.
     */
    function cancelRequest(
        uint256[] memory payload,
        uint256 nonce
    ) external;
}
