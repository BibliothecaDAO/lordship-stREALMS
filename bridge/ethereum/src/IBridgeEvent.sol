// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBridgeEvent {

    /**
       @notice Request initiated on L1.
    */
    event DepositRequestInitiated(
        uint256 indexed hash,
        uint256 blockTimestamp,
        uint256[] reqContent
    );

    /**
       @notice Request from L2 completed.
    */
    event WithdrawRequestCompleted(
        uint256 indexed hash,
        uint256 blockTimestamp,
        uint256[] reqContent
    );

    /**
        @notice A request cancellation is started
    */
    event CancelRequestStarted(
        uint256 indexed hash,
        uint256 blockTimestamp
    );

    /**
        @notice A request cancellation is completed
    */
    event CancelRequestCompleted(
        uint256 indexed hash,
        uint256 blockTimestamp
    );

}