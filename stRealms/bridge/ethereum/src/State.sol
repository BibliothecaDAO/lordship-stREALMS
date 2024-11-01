// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sn/Cairo.sol";

import "starknet/IStarknetMessaging.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 @title Bridge state.
*/
contract BridgeState is Ownable {

    // StarknetCore.
    IStarknetMessaging _starknetCoreAddress;

    // Bridge L2 address for messaging.
    snaddress _l2BridgeAddress;

    // Bridge L2 selector to deposit token from L1.
    felt252 _l2BridgeSelector;

    // l1 ERC721 contract address
    address _l1TokenAddress;


    /**
       @notice Retrieves info about Bridge L2 mapping.

       @return (realms L2 address, realms L2 selector).
    */
    function l2Info()
        external
        view
        returns (snaddress, felt252)
    {
        return (_l2BridgeAddress, _l2BridgeSelector);
    }

    /**
       @notice Sets Bridge L2 address.

       @param l2Address Bridge L2 address.
    */
    function setL2BridgeAddress(
        uint256 l2Address
    )
        public
        onlyOwner
    {
        _l2BridgeAddress = Cairo.snaddressWrap(l2Address);
    }

    /**
       @notice Sets Bridge L2 selector of Bridge L2 contract to be
       called when a message arrives into Starknet.

       @param l2Selector Bridge L2 selector.
    */
    function setL2BridgeSelector(
        uint256 l2Selector
    )
        public
        onlyOwner
    {
        _l2BridgeSelector = Cairo.felt252Wrap(l2Selector);
    }


    function l1TokenAddress() public view virtual returns (address) {
        return _l1TokenAddress;
    }

    function l2BridgeAddress() public view virtual returns (snaddress) {
        return _l2BridgeAddress;
    }

    function l2BridgeSelector() public view virtual returns (felt252) {
        return _l2BridgeSelector;
    }
}
