// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sn/Cairo.sol";
import "./Protocol.sol";
import "./State.sol";
import "./Escrow.sol";
import "./UUPSProxied.sol";

import "starknet/IStarknetMessaging.sol";

import "./IBridgeEvent.sol";


/**
   @title ERC721 bridge contract.
*/
contract Bridge is IBridgeEvent, UUPSOwnableProxied, BridgeState, BridgeEscrow {

    /**
       @notice Initializes the implementation, only callable once.

       @param data Data to init the implementation.
    */
    function initialize( bytes calldata data) public onlyInit{
        (
            address owner,
            address l1TokenAddress,
            IStarknetMessaging starknetCoreAddress,
            uint256 l2BridgeAddress,
            uint256 l2BridgeSelector
        ) = abi.decode(
            data,
            (address, address, IStarknetMessaging, uint256, uint256)
        );
        _starknetCoreAddress = starknetCoreAddress;
        _l1TokenAddress = l1TokenAddress;

        _transferOwnership(owner);

        setL2BridgeAddress(l2BridgeAddress);
        setL2BridgeSelector(l2BridgeSelector);
    }

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
        payable
    {
        if (!Cairo.isFelt252(snaddress.unwrap(ownerL2))) {
            revert CairoWrapError();
        }

        address l1TokenAddress = _l1TokenAddress;
        _depositIntoEscrow(l1TokenAddress, ids);

        Request memory req;
        req.hash = Protocol.requestHash(salt, ownerL2, ids);
        req.ownerL1 = msg.sender;
        req.ownerL2 = ownerL2;
        req.tokenIds = ids;

        uint256[] memory payload = Protocol.requestSerialize(req);

        IStarknetMessaging(_starknetCoreAddress).sendMessageToL2{value: msg.value}(
            snaddress.unwrap(_l2BridgeAddress),
            felt252.unwrap(_l2BridgeSelector),
            payload
        );

        emit DepositRequestInitiated(req.hash, block.timestamp, payload);
    }

    /**
       @notice Withdraw tokens received from L2.

       @param request Serialized request containing the tokens to be withdrawed. 
    */
    function withdrawTokens(uint256[] calldata request)
        external
        payable
    {

        //todo @credence0x check if hash from msh consumption should be used
        _starknetCoreAddress.consumeMessageFromL2(
                snaddress.unwrap(_l2BridgeAddress),
                request
            );
            

        Request memory req = Protocol.requestDeserialize(request);

        _withdrawFromEscrow(_l1TokenAddress, req.ownerL1, req.tokenIds);

        emit WithdrawRequestCompleted(req.hash, block.timestamp, request);

    }

    //todo @credence0x should onlyAdmin be able to start cancellation?
    /**
        @notice Start the cancellation of a given request.
     
        @param payload Request to cancel
        @param nonce Nonce used for request sending.
     */
    function startRequestCancellation(
        uint256[] memory payload,
        uint256 nonce
    ) external onlyOwner {
        IStarknetMessaging(_starknetCoreAddress).startL1ToL2MessageCancellation(
            snaddress.unwrap(_l2BridgeAddress), 
            felt252.unwrap(_l2BridgeSelector), 
            payload,
            nonce
        );
        Request memory req = Protocol.requestDeserialize(payload);
        emit CancelRequestStarted(req.hash, block.timestamp);
    }

    /**
        @notice Cancel a given request.

        @param payload Request to cancel
        @param nonce Nonce used for request sending.
     */
    function cancelRequest(
        uint256[] memory payload,
        uint256 nonce
    ) external {
        IStarknetMessaging(_starknetCoreAddress).cancelL1ToL2Message(
            snaddress.unwrap(_l2BridgeAddress), 
            felt252.unwrap(_l2BridgeSelector), 
            payload,
            nonce
        );
        Request memory req = Protocol.requestDeserialize(payload);
        _withdrawFromEscrow(_l1TokenAddress, req.ownerL1, req.tokenIds);

        emit CancelRequestCompleted(req.hash, block.timestamp);
    }

}
