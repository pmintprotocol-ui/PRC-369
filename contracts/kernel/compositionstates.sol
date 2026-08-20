// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Composition States
/// @author MINTer
/// @notice Defines the canonical lifecycle states of a PRC-369 Composition.
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
/// - No business logic
///
/// This library defines only the canonical lifecycle vocabulary.
/// State transitions are enforced by runtime components.

library CompositionStates {

    //////////////////////////////////////////////////////////////
    // INITIAL STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition has been created but not configured.
    PositionStateId internal constant CREATED =
        PositionStateId.wrap(1);

    /// @notice Composition is being configured.
    PositionStateId internal constant CONFIGURING =
        PositionStateId.wrap(2);

    //////////////////////////////////////////////////////////////
    // VALIDATION STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition has satisfied its structural requirements.
    PositionStateId internal constant READY =
        PositionStateId.wrap(3);

    //////////////////////////////////////////////////////////////
    // EXECUTION STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition execution is currently in progress.
    PositionStateId internal constant EXECUTING =
        PositionStateId.wrap(4);

    /// @notice Composition execution completed successfully.
    PositionStateId internal constant COMPLETED =
        PositionStateId.wrap(5);

    //////////////////////////////////////////////////////////////
    // TERMINAL STATES
    //////////////////////////////////////////////////////////////

    /// @notice Composition was cancelled before completion.
    PositionStateId internal constant CANCELLED =
        PositionStateId.wrap(6);

    /// @notice Composition failed during execution.
    PositionStateId internal constant FAILED =
        PositionStateId.wrap(7);

}
