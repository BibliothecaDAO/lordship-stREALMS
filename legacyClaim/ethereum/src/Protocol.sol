// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./sn/Cairo.sol";


struct Request {
    address ownerL1;
    snaddress ownerL2;
    uint16 claimId;
}



/**
   @title Library related to the protocol for bridging tokens.
*/
library Protocol {


    // Length of a Request when serialized into a cairo felt array
    function requestSerializedLength()
        internal
        pure
        returns (uint256)
    {
        // Also, the serialized length of uint256 in cairo, is 2. i.e 2 uint128 slots
        // so 1. ownerL1( l1 address) fits in 1 felt252
        //    2. ownerL2( starknet address) fits in 1 felt252
        //    3. claimId( u16 ) fits in 1 felt252
        //    total = 3.
        return 3;
    }


    /**
       @notice Serializes a deposit Request object into a starknet felt252 array

       @param req Request to serialize.

       @return uint256[] with the serialized request.
    */
    function requestSerialize(
        Request memory req
    )
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory buf = new uint256[](requestSerializedLength());

        // l1 ethereum address takes 1 felt252
        // note it is only converted to u256 but is always less than felt252
        buf[0] = uint256(uint160(req.ownerL1));

        // l2 starknet address takes 1 felt252
        buf[1] = snaddress.unwrap(req.ownerL2);

        // claim id takes 1 felt252
        buf[2] = uint256(req.claimId);

        return buf;
    }
}
