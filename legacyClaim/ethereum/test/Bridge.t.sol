// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "../src/IBridge.sol";
import "../src/IBridgeEvent.sol";

import "../src/Bridge.sol";
import "../src/sn/Cairo.sol";
import "../src/sn/StarknetMessagingLocal.sol";
import "../src/sn/IStarknetMessagingLocal.sol";
import "./utils/Users.sol";

/**
   @title Bridge testing.
*/
contract BridgeTest is Test, IBridgeEvent {

    address bridge;
    address erc721C1;
    address erc1155C1;
    address snCore;

    address payable internal alice;
    address payable internal bob;

    //
    function setUp() public {
        Users genusers = new Users();
        address payable[] memory users = genusers.create(5);
        alice = users[0];
        bob = users[1];

        address impl = address(new Bridge());
        snCore = address(new StarknetMessagingLocal());
        address l2bridgeAddress = address(0x56215);
        address l2bridgeSelector = address(0x9981726);
        bytes memory dataInit = abi.encodeWithSelector(
            Bridge.initialize.selector,
            abi.encode(
                address(this),
                snCore,
                l2bridgeAddress,
                l2bridgeSelector
            )
        );

        bridge = address(new ERC1967Proxy(impl, dataInit));
    }

    function buildRequest(uint16 claimId, address ownerL1) public pure returns (Request memory) {

        Request memory req = Request ({
            ownerL1: ownerL1,
            ownerL2: Cairo.snaddressWrap(0x800),
            claimId: claimId
        });

        return req;
    }


    //
    function test_claim() public {
        snaddress recipientOnStarknet = Cairo.snaddressWrap(0x1);
        uint16 claimId = 44;

        vm.startPrank(alice);
        vm.recordLogs();
        IBridge(bridge).claimOnStarknet{value: 30000}(
            recipientOnStarknet,
            claimId
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // 2 i.e LogMessageToL2 -> ClaimRequestInitiated
        assertEq(entries.length, 2);
        Vm.Log memory logMessageToL2 = entries[0];
        Vm.Log memory claimRequestInitiated = entries[1];
        (uint256[] memory payload, , ) = abi.decode(logMessageToL2.data, (uint256[], uint256, uint256));
        (uint256[] memory reqContent) = abi.decode(claimRequestInitiated.data, (uint256[]));
        assert(payload.length == reqContent.length);
        assertEq(reqContent[0], uint256(uint160(address(alice))));
        assertEq(reqContent[1], snaddress.unwrap(recipientOnStarknet));
        assertEq(reqContent[2], claimId);
    }

    //
    function testFail_claim_zeroAddressRecipient() public {
        snaddress recipientOnStarknet = Cairo.snaddressWrap(0x0);
        uint16 claimId = 44;

        vm.startPrank(alice);
        IBridge(bridge).claimOnStarknet{value: 30000}(
            recipientOnStarknet,
            claimId
        );
        vm.stopPrank();

    }
}
