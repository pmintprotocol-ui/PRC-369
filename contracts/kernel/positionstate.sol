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
///
/// Every Position has a mutable runtime state that evolves throughout
/// its lifecycle while preserving its immutable identity.
struct PositionRuntime {

    //////////////////////////////////////////////////////////////
    // LIFECYCLE
    //////////////////////////////////////////////////////////////

    /// @notice Current lifecycle state.
    PositionStateId stateId;

    //////////////////////////////////////////////////////////////
    // EVOLUTION
    //////////////////////////////////////////////////////////////

    /// @notice Current semantic generation.
    Generation generation;

    /// @notice Current Position nonce.
    PositionNonce nonce;

    /// @notice Runtime semantic version.
    VersionId version;

    //////////////////////////////////////////////////////////////
    // CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Active capability set.
    CapabilityMask capabilities;

}
