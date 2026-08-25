// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Composition Types
/// @author MINTer
/// @notice Defines the primitive semantic types used by PRC-369
///         Composition modules.
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
/// This file defines only Composition-specific primitive types
/// that are NOT already defined by Types.sol.

//////////////////////////////////////////////////////////////
// COMPOSITION OPERATION TYPES
//////////////////////////////////////////////////////////////

/// @notice Unique identifier of a Composition operation type.
type CompositionOperationId is bytes32;

/// @notice Identifier of a Composition source group.
type CompositionGroupId is bytes32;
