// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./sn/Cairo.sol";

interface IBridgeEvent {

    /**
       @notice Request initiated on L1.
    */
    event ClaimRequestInitiated(
        address indexed ownerL1,
        snaddress indexed ownerL2,
        uint256[] reqContent
    );
}