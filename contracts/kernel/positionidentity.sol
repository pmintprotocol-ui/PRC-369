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

//////////////////////////////////////////////////////////////
// POSITION DESCRIPTOR
//////////////////////////////////////////////////////////////

/// @notice Immutable identity descriptor of a Position.
struct PositionDescriptor {
    /// @notice Protocol namespace.
    ProtocolId protocol;

    /// @notice Canonical economic class.
    PositionClassId classId;

    /// @notice Implementation-specific family.
    PositionFamilyId familyId;

    /// @notice Semantic version.
    Version version;
}

//////////////////////////////////////////////////////////////
// POSITION DEFINITION
//////////////////////////////////////////////////////////////

/// @notice Complete immutable definition of a Position.
struct PositionDefinition {
    /// @notice Immutable identity.
    PositionDescriptor descriptor;

    /// @notice Supported capabilities.
    CapabilityMask capabilities;
}
