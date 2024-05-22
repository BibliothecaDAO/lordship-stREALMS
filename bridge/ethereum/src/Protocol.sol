// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./sn/Cairo.sol";


struct Request {
    uint256 hash;
    address ownerL1;
    snaddress ownerL2;
    uint256[] tokenIds;
}



/**
   @title Library related to the protocol for bridging tokens.
*/
library Protocol {

    /**
       @notice Computes the request hash.

       @param salt Random salt.
       @param toL2Address New owner on Starknet (L2).
       @param tokenIds List of token ids to be transfered.

       @return Request hash.
    */
    function requestHash(
        uint256 salt,
        snaddress toL2Address,
        uint256[] memory tokenIds
    )
        internal
        pure
        returns (uint256)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                salt,
                // Cairo uses felts, which are converted into u256 to compute keccak.
                // As we use abi.encodePacked, we want the address to also be 32 bytes long.
                snaddress.unwrap(toL2Address),
                tokenIds
            )
        );

        return uint256(hash);
    }

    // Length of a Request when serialized into a cairo felt array
    function requestSerializedLength(
        Request memory req
    )
        internal
        pure
        returns (uint256)
    {
        // Also, the serialized length of uint256 in cairo, is 2. i.e 2 uint128 slots
        // so 1. hash (uint256) takes 2 felt252 slots 
        //    2. ownerL1( l1 address) fits in 1 felt252
        //    3. ownerL2( starknet address) fits in 1 felt252
        //    total = 4.

        uint256 len = 4;

        // when serializing an array in cairo, the length of the array comes first, 
        // then serialized length of each element.
        // Also, the serialized length of uint256 in cairo, is 2. i.e 2 uint128 slots
        // so we end up with (tokenIds.length * 2 (serialized uint) + 1 (array length))
        len += (req.tokenIds.length * 2) + 1; 
     
        return len;
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
        uint256[] memory buf = new uint256[](requestSerializedLength(req));

        // hash is split into 2 felts
        buf[0] = uint128(req.hash);
        buf[1] = uint128(req.hash >> 128);

        // l1 ethereum address takes 1 felt252
        // note it is only converted to u256 but is always less than felt252
        buf[2] = uint256(uint160(req.ownerL1));

        // l2 starknet address takes 1 felt252
        buf[3] = snaddress.unwrap(req.ownerL2);

        // Variable length part of the request.
        uint256 offset = 4;
        offset += Cairo.uint256ArraySerialize(req.tokenIds, buf, offset);

        return buf;
    }

    /**
       @notice Deserializes a starknet felt array into a Request object

       @param buf Uint256[] buffer with the serialized request.

       @return Request.
    */
    function requestDeserialize(uint256[] memory buf)
        internal
        pure
        returns (Request memory)
    {

        uint256 offset = 0;
        Request memory req;

        req.hash = Cairo.uint256Deserialize(buf, offset);
        offset += 2;

        req.ownerL1 = address(uint160(buf[offset++]));
        req.ownerL2 = Cairo.snaddressWrap(buf[offset++]);

        uint256 inc;
        (inc, req.tokenIds) = Cairo.uint256ArrayDeserialize(buf, offset);
        offset += inc;

        return req;
    }

}
