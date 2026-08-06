// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Kernel Events
/// @author MINTer
/// @notice Defines all canonical events emitted by the PRC-369 ecosystem.
/// @dev Part of the immutable PRC-369 Kernel.
///
/// IMPORTANT:
/// Every implementation should reuse these events whenever possible.
/// New modules should extend this library instead of redefining events.
library Events {

    /*//////////////////////////////////////////////////////////////
                            POSITION
    //////////////////////////////////////////////////////////////*/

    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner
    );

    event PositionTransferred(
        uint256 indexed positionId,
        address indexed from,
        address indexed to
    );

    event PositionUpdated(
        uint256 indexed positionId
    );

    event PositionClosed(
        uint256 indexed positionId
    );

    /*//////////////////////////////////////////////////////////////
                            RESERVE
    //////////////////////////////////////////////////////////////*/

    event ReserveRegistered(
        uint256 indexed reserveId,
        uint8 indexed reserveType,
        address indexed owner
    );

    event ReserveReleased(
        uint256 indexed reserveId
    );

    /*//////////////////////////////////////////////////////////////
                             RIGHTS
    //////////////////////////////////////////////////////////////*/

    event RightsTransferred(
        uint256 indexed positionId,
        address indexed from,
        address indexed to
    );

    event RewardsClaimed(
        uint256 indexed positionId,
        address indexed account,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                              VAULT
    //////////////////////////////////////////////////////////////*/

    event Deposited(
        uint256 indexed reserveId,
        address indexed owner
    );

    event Withdrawn(
        uint256 indexed reserveId,
        address indexed owner
    );

    /*//////////////////////////////////////////////////////////////
                           SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    event SettlementExecuted(
        uint256 indexed positionId,
        uint256 value
    );

    /*//////////////////////////////////////////////////////////////
                           ADAPTER
    //////////////////////////////////////////////////////////////*/

    event AdapterRegistered(
        uint8 indexed reserveType,
        address indexed adapter
    );

    event AdapterRemoved(
        uint8 indexed reserveType
    );

}
