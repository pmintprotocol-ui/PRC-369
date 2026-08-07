// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Position States
/// @author MINTer
/// @notice Defines the canonical lifecycle states of PRC-369 Positions.
/// @dev
/// Part of the immutable PRC-369 Kernel.
///
/// DESIGN PRINCIPLES
/// - No storage
/// - No functions
/// - No structs
/// - No enums
/// - No events
/// - No errors
///
/// This library defines the canonical lifecycle states shared by all
/// PRC-369 compliant implementations.
///
/// Position states represent the mutable lifecycle of a Position.
/// State transitions are enforced by the Runtime and MUST respect the
/// Kernel invariants.
library PositionStates {

    //////////////////////////////////////////////////////////////
    // INITIAL STATES
    //////////////////////////////////////////////////////////////

    /// @notice Position has been created but is not yet active.
    PositionStateId internal constant CREATED =
        PositionStateId.wrap(1);

    //////////////////////////////////////////////////////////////
    // ACTIVE STATES
    //////////////////////////////////////////////////////////////

    /// @notice Position is active and fully operational.
    PositionStateId internal constant ACTIVE =
        PositionStateId.wrap(2);

    /// @notice Position is temporarily locked.
    PositionStateId internal constant LOCKED =
        PositionStateId.wrap(3);

    //////////////////////////////////////////////////////////////
    // TERMINAL STATES
    //////////////////////////////////////////////////////////////

    /// @notice Position has been redeemed.
    PositionStateId internal constant REDEEMED =
        PositionStateId.wrap(4);

    /// @notice Position has been settled.
    PositionStateId internal constant SETTLED =
        PositionStateId.wrap(5);

    /// @notice Position has been archived.
    PositionStateId internal constant ARCHIVED =
        PositionStateId.wrap(6);

}
