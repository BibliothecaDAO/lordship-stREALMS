// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sn/Cairo.sol";

import "starknet/IStarknetMessaging.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 @title Realms state.
*/
contract RealmsState is Ownable {

    // StarknetCore.
    IStarknetMessaging _starknetCoreAddress;

    // Realms L2 address for messaging.
    snaddress _realmsBridgeL2Address;

    // Bridge L2 selector to deposit token from L1.
    felt252 _realmsBridgeL2Selector;

    // realms ERC721 contract address
    address _realmContractAddress;


    /**
       @notice Retrieves info about Realms L2 mapping.

       @return (realms L2 address, realms L2 selector).
    */
    function l2Info()
        external
        view
        returns (snaddress, felt252)
    {
        return (_realmsBridgeL2Address, _realmsBridgeL2Selector);
    }

    /**
       @notice Sets Realms L2 address.

       @param l2Address Realms L2 address.
    */
    function setRealmsBridgeL2Address(
        uint256 l2Address
    )
        public
        onlyOwner
    {
        _realmsBridgeL2Address = Cairo.snaddressWrap(l2Address);
    }

    /**
       @notice Sets Realms L2 selector of Realms L2 contract to be
       called when a message arrives into Starknet.

       @param l2Selector Realms L2 selector.
    */
    function setRealmsBridgeL2Selector(
        uint256 l2Selector
    )
        public
        onlyOwner
    {
        _realmsBridgeL2Selector = Cairo.felt252Wrap(l2Selector);
    }


}
