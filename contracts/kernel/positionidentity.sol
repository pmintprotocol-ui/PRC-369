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
/// This file defines the canonical immutable identity model shared by
/// all PRC-369 compliant implementations.
///
/// Position identity never changes during the lifetime of a Position.
/// Runtime evolution is handled separately by PositionRuntime.sol.

//////////////////////////////////////////////////////////////
// POSITION DESCRIPTOR
//////////////////////////////////////////////////////////////

/// @notice Canonical semantic descriptor of a Position.
///
/// @dev
/// The descriptor defines the economic classification of a Position
/// independently of its runtime state or implementation details.
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

    /// @notice Semantic version supported by this Position.
    Version version;
}

//////////////////////////////////////////////////////////////
// POSITION IDENTITY
//////////////////////////////////////////////////////////////

/// @notice Complete immutable identity of a Position.
///
/// @dev
/// PositionIdentity combines the semantic descriptor with the
/// immutable capability set supported by the Position.
///
/// Once created, this structure MUST NEVER be modified.
struct PositionIdentity {

    /// @notice Canonical semantic descriptor.
    PositionDescriptor descriptor;

    /// @notice Immutable capability set supported by the Position.
    CapabilityMask capabilities;
}
