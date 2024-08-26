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

        Request memory req = Request ({
            ownerL1: address(0x700),
            ownerL2: Cairo.snaddressWrap(0x800),
            claimId: 676
        });

        return req;
    }


    //
    function test_requestSerializedLength() public {
        assertEq(Protocol.requestSerializedLength(), 3);
    }

    //
    function test_requestSerialize() public {
        Request memory req = buildRequestDummySmall();
        uint256[] memory buf = Protocol.requestSerialize(req);
        assertEq(buf.length, Protocol.requestSerializedLength());
        assertEq(buf[0], 0x700);
        assertEq(buf[1], 0x800);
        assertEq(buf[2], 676);
    }
}
