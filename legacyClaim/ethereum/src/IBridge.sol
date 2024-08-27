// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sn/Cairo.sol";

/**
 */
interface IBridge {
    /**
       @notice Claim staking reward on starknet

       @param ownerL2 the address the reward will be sent to on starknet
       @param claimId the claim id
    */
    function claimOnStarknet(snaddress ownerL2, uint16 claimId)
        external
        payable;
}
