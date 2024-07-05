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
import "./token/ERC721MintFree.sol";
import "./token/IERC721MintRangeFree.sol";

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

        erc721C1 = address(new ERC721MintFree("name 1", "S1"));

        snCore = address(new StarknetMessagingLocal());

        address impl = address(new Bridge());
        address l2bridgeAddress = address(0x56215);
        address l2bridgeSelector = address(0x9981726);
        
        bytes memory dataInit = abi.encodeWithSelector(
            Bridge.initialize.selector,
            abi.encode(
                address(this),
                erc721C1,
                snCore,
                l2bridgeAddress,
                l2bridgeSelector
            )
        );

        bridge = address(new ERC1967Proxy(impl, dataInit));
    }

    function buildRequest(uint256 tokenId, address ownerL1) public pure returns (Request memory) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;

        Request memory req = Request ({
            hash: type(uint128).max, // max u128 so it takes 1 felt252 slot
            ownerL1: ownerL1,
            ownerL2: Cairo.snaddressWrap(0x800),
            tokenIds: ids
        });

        return req;
    }


    //
    function testFail_nodIds() public {
        uint256[] memory ids = new uint256[](0);

        uint256 salt = 0x1;
        snaddress to = Cairo.snaddressWrap(0x1);

        IBridge(bridge).depositTokens{value: 30000}(
            salt,
            to,
            ids
        );
    }

    function test_invalidL2Owner() public {

        IERC721MintRangeFree(erc721C1).mintRangeFree(alice, 0, 10);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256 salt = 0x1;
        snaddress to = snaddress.wrap(SN_MODULUS);

        vm.startPrank(alice);
        IERC721(erc721C1).setApprovalForAll(bridge, true);
        vm.expectRevert(CairoWrapError.selector);
        IBridge(bridge).depositTokens{value: 30000}(
            salt,
            to,
            ids
        );
    }



    //
    function test_depositTokenERC721() public {
        IERC721MintRangeFree(erc721C1).mintRangeFree(alice, 0, 10);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 9;

        uint256 salt = 0x1;
        snaddress to = Cairo.snaddressWrap(0x1);

        vm.startPrank(alice);
        IERC721(erc721C1).setApprovalForAll(address(bridge), true);
        IBridge(bridge).depositTokens{value: 30000}(
            salt,
            to,
            ids
        );
        vm.stopPrank();

        assert(IERC721(erc721C1).balanceOf(bridge) == 2);
        assert(IERC721(erc721C1).ownerOf(1) == bridge);
        assert(IERC721(erc721C1).ownerOf(9) == bridge);
    }



    function test_withdrawTokens() public {
        // deposit token to bridge contract
        IERC721MintRangeFree(erc721C1).mintRangeFree(alice, 888, 889);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 888;
        uint256 salt = 0x1;
        snaddress to = Cairo.snaddressWrap(0x1);
        vm.startPrank(alice);
        IERC721(erc721C1).setApprovalForAll(address(bridge), true);
        IBridge(bridge).depositTokens{value: 30000}(
            salt,
            to,
            ids
        );
        vm.stopPrank();

        // build withdraw Request object with bob as recipient
        Request memory req = buildRequest(888, bob);
        uint256[] memory reqSerialized = Protocol.requestSerialize(req);
        bytes32 msgHash = computeMessageHashFromL2(reqSerialized);

        // The message must be simulated to come from starknet verifier contract
        // on L1 and pushed to starknet core.
        uint256[] memory msgHashes = new uint256[](1);
        msgHashes[0] = uint256(msgHash);
        IStarknetMessagingLocal(snCore).addMessageHashesFromL2(msgHashes);
        IBridge(bridge).withdrawTokens(reqSerialized);

        assertEq(IERC721(erc721C1).ownerOf(888), bob);
        // Error message from Starknet Core expected 
        // when you consume the same message twice
        vm.expectRevert(bytes("INVALID_MESSAGE_TO_CONSUME"));
        IBridge(bridge).withdrawTokens(reqSerialized);
    }




    function test_cancelRequest() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 9;

        (uint256 nonce, uint256[] memory payload) = setupCancelRequest(alice, ids);
        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);

        Request memory req = Protocol.requestDeserialize(payload);

        vm.expectEmit(true, false, false, false, bridge);
        emit CancelRequestStarted(req.hash, 42);
        IBridge(bridge).startRequestCancellation(payload, nonce);

        vm.expectEmit(true, false, false, false, bridge);
        emit CancelRequestCompleted(req.hash, 42);
        IBridge(bridge).cancelRequest(payload, nonce);

        assert(IERC721(erc721C1).ownerOf(ids[0]) == alice);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == alice);
    }

    function test_startRequestCancellation_notAdminOrOwner() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 9;

        (uint256 nonce, uint256[] memory payload) = setupCancelRequest(alice, ids);
        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);

        // bob does not own the tokens and is not admin
        vm.startPrank(bob);
        vm.expectRevert();
        IBridge(bridge).startRequestCancellation(payload, nonce);
        vm.stopPrank();

        vm.expectRevert();
        IBridge(bridge).cancelRequest(payload, nonce);

        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);
    }

    function test_startRequestCancellation_byTokenOwner() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 9;

        (uint256 nonce, uint256[] memory payload) = setupCancelRequest(alice, ids);
        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);


        // alice owns tokens so it should not revert
        vm.startPrank(alice);
        IBridge(bridge).startRequestCancellation(payload, nonce);
        vm.stopPrank();

        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);
    }

    function test_startRequestCancellation_byAdmin() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 9;

        (uint256 nonce, uint256[] memory payload) = setupCancelRequest(alice, ids);
        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);


        // admin call should not revert
        address admin = address(this);
        vm.startPrank(admin);
        IBridge(bridge).startRequestCancellation(payload, nonce);
        vm.stopPrank();

        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);
    }

    function test_cancelRequest_withDelay() public {
        uint256 delay = 30;
        IStarknetMessagingLocal(snCore).setMessageCancellationDelay(delay);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 9;

        (uint256 nonce, uint256[] memory payload) = setupCancelRequest(alice, ids);
        assert(IERC721(erc721C1).ownerOf(ids[0]) == bridge);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == bridge);

        Request memory req = Protocol.requestDeserialize(payload);

        vm.expectEmit(true, false, false, false, bridge);
        emit CancelRequestStarted(req.hash, 42);
        IBridge(bridge).startRequestCancellation(payload, nonce);

        vm.expectRevert("MESSAGE_CANCELLATION_NOT_ALLOWED_YET");
        IBridge(bridge).cancelRequest(payload, nonce);

        skip(delay * 1 seconds);
        IBridge(bridge).cancelRequest(payload, nonce);

        assert(IERC721(erc721C1).ownerOf(ids[0]) == alice);
        assert(IERC721(erc721C1).ownerOf(ids[1]) == alice);
    }


    //
    function computeMessageHashFromL2(
        uint256[] memory request
    )
        public
        returns (bytes32)
    {
        (snaddress l2BridgeAddress, felt252 l2BridgeSelector)
            = Bridge(payable(bridge)).l2Info();

        // To remove warning. Is there a better way?
        assertTrue(felt252.unwrap(l2BridgeSelector) > 0);

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                snaddress.unwrap(l2BridgeAddress),
                uint256(uint160(bridge)),
                request.length,
                request)
        );

        return msgHash;
    }

    function setupCancelRequest(
        address user,
        uint256[] memory tokenIds
    ) internal returns(uint256, uint256[] memory) {

        // deposit tokenIds to bridge through user
        IERC721MintRangeFree(erc721C1).mintRangeFree(user, 0, 10);
        uint256 salt = 0x1;
        snaddress to = Cairo.snaddressWrap(0x1);
        vm.startPrank(user);
        IERC721(erc721C1).setApprovalForAll(bridge, true);
        vm.recordLogs();
        IBridge(bridge).depositTokens{value: 30000}(
            salt,
            to,
            tokenIds
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        // Transfer - Transfer - LogMessageToL2 - DepositRequestInitialized
        assertEq(entries.length, 4);
        Vm.Log memory logMessageToL2 = entries[2];
        Vm.Log memory depositRequestEvent = entries[3];
        (uint256[] memory payload, uint256 nonce, ) = abi.decode(logMessageToL2.data, (uint256[], uint256, uint256));
        ( ,uint256[] memory reqContent) = abi.decode(depositRequestEvent.data, (uint256, uint256[]));
        assert(payload.length == reqContent.length);
        return (nonce, payload);
    }

}
