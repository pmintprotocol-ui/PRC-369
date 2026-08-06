// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Position State
/// @author MINTer
/// @notice Defines the mutable runtime state of a Position.
/// @dev
/// Part of the immutable PRC-369 Kernel.
///
/// DESIGN PRINCIPLES
/// - No storage
/// - No functions
/// - No events
/// - No errors
/// - No business logic
///
/// This file defines the canonical runtime state model shared by all
/// PRC-369 compliant implementations.

//////////////////////////////////////////////////////////////
// POSITION RUNTIME
//////////////////////////////////////////////////////////////

/// @notice Mutable runtime state of a Position.
struct PositionRuntime {
    /// @notice Current lifecycle state identifier.
    PositionStateId stateId;

    /// @notice Current generation of the Position.
    Generation generation;

    /// @notice Monotonically increasing Position nonce.
    PositionNonce nonce;
}
