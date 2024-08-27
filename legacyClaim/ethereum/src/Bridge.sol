// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sn/Cairo.sol";
import "./Protocol.sol";
import "./State.sol";
import "./UUPSProxied.sol";

import "starknet/IStarknetMessaging.sol";

import "./IBridgeEvent.sol";


/**
   @title Lords claim bridge contract.
*/
contract Bridge is IBridgeEvent, UUPSOwnableProxied, BridgeState {
    error ZeroAddressError();

    /**
       @notice Initializes the implementation, only callable once.

       @param data Data to initialize the implementation.
    */
    function initialize( bytes calldata data) public onlyInit{
        (
            address owner,
            IStarknetMessaging starknetCoreAddress,
            uint256 l2BridgeAddress,
            uint256 l2BridgeSelector
        ) = abi.decode(
            data,
            (address, IStarknetMessaging, uint256, uint256)
        );
        _starknetCoreAddress = starknetCoreAddress;
        _transferOwnership(owner);

        setL2BridgeAddress(l2BridgeAddress);
        setL2BridgeSelector(l2BridgeSelector);
    }

    /**
       @notice Claim staking reward on starknet

       @param ownerL2 the address the reward will be sent to on starknet
       @param claimId the claim id
    */
    function claimOnStarknet(snaddress ownerL2, uint16 claimId)
        external
        payable
    {
        if (!Cairo.isFelt252(snaddress.unwrap(ownerL2))) {
            revert CairoWrapError();
        }

        if (snaddress.unwrap(ownerL2) == 0x0) {
            revert ZeroAddressError();
        }

        Request memory req;
        req.ownerL1 = msg.sender;
        req.ownerL2 = ownerL2;
        req.claimId = claimId;

        uint256[] memory payload = Protocol.requestSerialize(req);

        IStarknetMessaging(_starknetCoreAddress).sendMessageToL2{value: msg.value}(
            snaddress.unwrap(_l2BridgeAddress),
            felt252.unwrap(_l2BridgeSelector),
            payload
        );

        emit ClaimRequestInitiated(req.ownerL1, req.ownerL2, payload);
    }

}
