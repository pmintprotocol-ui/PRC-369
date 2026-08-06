// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

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
// POSITION VERSION
//////////////////////////////////////////////////////////////

/// @notice Semantic version of a Position Family.
struct PositionVersion {
    uint16 major;
    uint16 minor;
    uint16 patch;
}

//////////////////////////////////////////////////////////////
// POSITION DESCRIPTOR
//////////////////////////////////////////////////////////////

/// @notice Immutable identity descriptor of a Position.
struct PositionDescriptor {
    ProtocolId protocol;
    PositionClassId classId;
    PositionFamilyId familyId;
    PositionVersion version;
}

//////////////////////////////////////////////////////////////
// POSITION DEFINITION
//////////////////////////////////////////////////////////////

/// @notice Complete immutable definition of a Position.
struct PositionDefinition {
    PositionDescriptor descriptor;
    CapabilityMask capabilities;
}
