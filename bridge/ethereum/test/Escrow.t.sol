// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import "forge-std/Test.sol";

import "../src/Escrow.sol";

import "./utils/Users.sol";
import "./token/ERC721MintFree.sol";
import "./token/IERC721MintRangeFree.sol";

/**
   @title Escrow testing.
*/
contract EscrowTest is Test {

    EscrowPublic escrow;
    address erc721;

    address payable internal alice;
    address payable internal bob;

    //
    function setUp() public {
        escrow = new EscrowPublic();
        erc721 = address(new ERC721MintFree("name 1", "S1"));

        Users genusers = new Users();
        address payable[] memory users = genusers.create(5);
        alice = users[0];
        bob = users[1];

        vm.prank(alice);
        IERC721(erc721).setApprovalForAll(address(escrow), true);
        vm.prank(bob);
        IERC721(erc721).setApprovalForAll(address(escrow), true);
    }

    //
    function test_deposit() public {
        IERC721MintRangeFree(erc721).mintRangeFree(alice, 0, 10);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 5;
        ids[1] = 8;

        vm.prank(alice);
        escrow.depositIntoEscrow(erc721, ids);

        assert(IERC721(erc721).ownerOf(5) == address(escrow));
        assert(IERC721(erc721).ownerOf(8) == address(escrow));
    }

    //
    function testFail_depositNoIds() public {
        uint256[] memory ids = new uint256[](0);
        escrow.depositIntoEscrow(erc721, ids);
    }

    //
    function test_withdraw() public {
        IERC721MintRangeFree(erc721).mintRangeFree(alice, 0, 10);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 5;
        ids[1] = 8;

        vm.startPrank(alice);
        escrow.depositIntoEscrow(erc721, ids);
        escrow.withdrawFromEscrow(erc721, bob, ids);
        vm.stopPrank();

        assertEq(IERC721(erc721).ownerOf(5), bob);
        assertEq(IERC721(erc721).ownerOf(8), bob);
    }
}

/**
   @title Escrow interface exposed for test.
 */
contract EscrowPublic is BridgeEscrow {

    /**
       @notice test _depositIntoEscrow.
    */
    function depositIntoEscrow(
        address collection,
        uint256[] memory ids
    )
        public
    {
        _depositIntoEscrow(collection, ids);
    }

    /**
       @notice test _withdrawFromEscrow.
    */
    function withdrawFromEscrow(
        address collection,
        address to,
        uint256[] memory ids
    )
        public
    {
        _withdrawFromEscrow(collection, to, ids);
    }
}
