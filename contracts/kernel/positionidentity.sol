// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";
import "./Version.sol";

/// @title PRC-369 Position Identity
/// @author MINTer
/// @notice Defines the immutable identity structures used by PRC-369 Positions.
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
/// This file defines the canonical identity model shared by all
/// PRC-369 compliant implementations.
///
/// Position identity is immutable throughout the entire lifecycle
/// of a Position.
//////////////////////////////////////////////////////////////
// POSITION DESCRIPTOR
//////////////////////////////////////////////////////////////

/// @notice Canonical semantic descriptor of a Position.
struct PositionDescriptor {

    //////////////////////////////////////////////////////////////
    // PROTOCOL
    //////////////////////////////////////////////////////////////

    /// @notice Protocol namespace.
    ProtocolId protocol;

    //////////////////////////////////////////////////////////////
    // CLASSIFICATION
    //////////////////////////////////////////////////////////////

    /// @notice Canonical Position Class.
    PositionClassId classId;

    /// @notice Implementation-specific Position Family.
    PositionFamilyId familyId;

    //////////////////////////////////////////////////////////////
    // VERSIONING
    //////////////////////////////////////////////////////////////

    /// @notice Semantic version.
    Version version;

}

//////////////////////////////////////////////////////////////
// POSITION IDENTITY
//////////////////////////////////////////////////////////////

/// @notice Complete immutable identity of a Position.
struct PositionIdentity {

    /// @notice Canonical descriptor.
    PositionDescriptor descriptor;

    /// @notice Supported capability set.
    CapabilityMask capabilities;

}
