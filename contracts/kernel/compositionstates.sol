// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Composition States
/// @author MINTer
/// @notice Defines the canonical lifecycle states of a PRC-369 Composition.
/// @dev
/// Part of the immutable PRC-369 Kernel.
///
/// Composition lifecycle states are independent from Position lifecycle
/// states.
///
/// PositionStateId belongs to Position.
/// CompositionStateId belongs to Composition.
///
/// DESIGN PRINCIPLES
/// - No storage
/// - No functions
/// - No structs
/// - No enums
/// - No events
/// - No errors
/// - No business logic
///
/// State transitions are enforced by Runtime components.

library CompositionStates {

    //////////////////////////////////////////////////////////////
    // INITIAL STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition has been created but not configured.
    CompositionStateId internal constant CREATED =
        CompositionStateId.wrap(1);

    /// @notice Composition is being configured.
    CompositionStateId internal constant CONFIGURING =
        CompositionStateId.wrap(2);

    //////////////////////////////////////////////////////////////
    // VALIDATION STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition has satisfied its structural requirements.
    CompositionStateId internal constant READY =
        CompositionStateId.wrap(3);

    //////////////////////////////////////////////////////////////
    // EXECUTION STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition execution is currently in progress.
    CompositionStateId internal constant EXECUTING =
        CompositionStateId.wrap(4);

    /// @notice Composition execution completed successfully.
    CompositionStateId internal constant COMPLETED =
        CompositionStateId.wrap(5);

    //////////////////////////////////////////////////////////////
    // TERMINAL STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition was cancelled before completion.
    CompositionStateId internal constant CANCELLED =
        CompositionStateId.wrap(6);

    /// @notice Composition failed during execution.
    CompositionStateId internal constant FAILED =
        CompositionStateId.wrap(7);
}
