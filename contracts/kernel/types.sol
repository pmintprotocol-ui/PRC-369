// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Kernel Types
/// @author MINTer
/// @notice Defines the primitive semantic types used throughout the PRC-369 standard.
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
/// This file only defines User Defined Value Types (UDVT).
///
/// Every other Kernel module builds upon these primitive domain types.

//////////////////////////////////////////////////////////////
/// IDENTITY TYPES
//////////////////////////////////////////////////////////////

/// @notice Unique identifier of a Position.
type PositionId is uint256;

/// @notice Unique identifier of a protocol namespace.
type ProtocolId is bytes32;

/// @notice Unique identifier of an Asset Adapter.
type AdapterId is bytes32;

/// @notice Unique identifier of a settlement operation.
type SettlementId is uint256;

/// @notice Unique identifier of an economic rights package.
type RightsId is uint256;

//////////////////////////////////////////////////////////////
/// VERSION TYPES
//////////////////////////////////////////////////////////////

/// @notice Position generation identifier.
type Generation is uint64;

/// @notice Position nonce.
type PositionNonce is uint64;

/// @notice Encoded semantic version identifier.
type VersionId is uint32;

//////////////////////////////////////////////////////////////
/// CLASSIFICATION TYPES
//////////////////////////////////////////////////////////////

/// @notice Position Class identifier.
type PositionClassId is uint16;

/// @notice Position Family identifier.
type PositionFamilyId is uint32;

//////////////////////////////////////////////////////////////
/// CAPABILITY TYPES
//////////////////////////////////////////////////////////////

/// @notice Bitmask representing supported capabilities.
type CapabilityMask is uint256;
