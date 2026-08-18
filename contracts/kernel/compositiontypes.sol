// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Composition Types
/// @author MINTer
/// @notice Defines the primitive semantic types used by PRC-369
/// composition operations.
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
/// This file defines only User Defined Value Types (UDVT).
/// Runtime composition modules build upon these primitive types.


//////////////////////////////////////////////////////////////
// COMPOSITION IDENTIFIERS
//////////////////////////////////////////////////////////////

/// @notice Unique identifier of a composition operation.
type CompositionId is bytes32;

/// @notice Unique identifier of a composition operation type.
type CompositionOperationId is bytes32;

/// @notice Identifier of a composition source group.
type CompositionGroupId is bytes32;
