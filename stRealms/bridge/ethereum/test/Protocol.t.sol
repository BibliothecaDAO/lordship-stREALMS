// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Protocol.sol";

/**
   @title Protocol testing.
*/
contract ProtocolTest is Test {

    //
    function setUp() public {
    }

    //
    function buildRequestDummySmall() public pure returns (Request memory) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        Request memory req = Request ({
            hash: type(uint128).max, // max u128 so it takes 1 felt252 slot
            ownerL1: address(0x700),
            ownerL2: Cairo.snaddressWrap(0x800),
            tokenIds: ids
        });

        return req;
    }

    //
    function buildRequestDummyFull() public pure returns (Request memory) {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        Request memory req = Request ({
            hash: type(uint256).max, // max u256 so it takes 2 felt252 slots
            ownerL1: address(0x700),
            ownerL2: Cairo.snaddressWrap(0x800),
            tokenIds: ids
        });

        return req;
    }

    //
    function test_requestSerializedLengthForSmallDummyRequest() public {
        Request memory req = buildRequestDummySmall();
        uint256 len = Protocol.requestSerializedLength(req);
        assertEq(len, 7);

        Request memory reqFull = buildRequestDummyFull();
        uint256 lenFull = Protocol.requestSerializedLength(reqFull);
        assertEq(lenFull, 11);
    }

    //
    function test_requestSerialize() public {
        Request memory req = buildRequestDummySmall();
        uint256[] memory buf = Protocol.requestSerialize(req);
        assertEq(buf.length, Protocol.requestSerializedLength(req));
        assertEq(buf[0], 0xffffffffffffffffffffffffffffffff);
        assertEq(buf[1], 0x0);
        assertEq(buf[2], 0x700);
        assertEq(buf[3], 0x800);
        assertEq(buf[4], 0x1);
        assertEq(buf[5], 0x1);
        assertEq(buf[6], 0x0);


        Request memory req2 = buildRequestDummyFull();
        uint256[] memory buf2 = Protocol.requestSerialize(req2);
        assertEq(buf2.length, Protocol.requestSerializedLength(req2));
        assertEq(buf2[0], 0xffffffffffffffffffffffffffffffff);
        assertEq(buf2[1], 0xffffffffffffffffffffffffffffffff);
        assertEq(buf2[2], 0x700);
        assertEq(buf2[3], 0x800);
        assertEq(buf2[4], 0x3);
        assertEq(buf2[5], 0x1);
        assertEq(buf2[6], 0x0);
        assertEq(buf2[7], 0x2);
        assertEq(buf2[8], 0x0);
        assertEq(buf2[9], 0x3);
        assertEq(buf2[10], 0x0);
    }

    //
    function test_requestDeserialize() public {
        // 1
        uint256[] memory data = new uint256[](7);
        data[0] = 0xffffffffffffffffffffffffffffffff;
        data[1] = 0x0;
        data[2] = 0x700;
        data[3] = 0x800;
        data[4] = 0x1;
        data[5] = 0x1;
        data[6] = 0x0;

        Request memory actualReq = buildRequestDummySmall();
        Request memory deserializedReq = Protocol.requestDeserialize(data);
        assertEq(actualReq.hash, deserializedReq.hash);
        assertEq(actualReq.ownerL1, deserializedReq.ownerL1);
        assertEq(snaddress.unwrap(actualReq.ownerL2), snaddress.unwrap(deserializedReq.ownerL2));
        assertEq(actualReq.tokenIds, deserializedReq.tokenIds);


        // 2
        uint256[] memory dataFull = new uint256[](11);
        dataFull[0] = 0xffffffffffffffffffffffffffffffff;
        dataFull[1] = 0xffffffffffffffffffffffffffffffff;
        dataFull[2] = 0x700;
        dataFull[3] = 0x800;
        dataFull[4] = 0x3;
        dataFull[5] = 0x1;
        dataFull[6] = 0x0;
        dataFull[7] = 0x2;
        dataFull[8] = 0x0;
        dataFull[9] = 0x3;
        dataFull[10] = 0x0;

        Request memory actualReqFull = buildRequestDummyFull();
        Request memory deserializedReqFull = Protocol.requestDeserialize(dataFull);
        assertEq(actualReqFull.hash, deserializedReqFull.hash);
        assertEq(actualReqFull.ownerL1, deserializedReqFull.ownerL1);
        assertEq(snaddress.unwrap(actualReqFull.ownerL2), snaddress.unwrap(deserializedReqFull.ownerL2));
        assertEq(actualReqFull.tokenIds, deserializedReqFull.tokenIds);
    }


}
