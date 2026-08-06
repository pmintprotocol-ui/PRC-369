// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Kernel Types
/// @author MINTer
/// @notice Defines the primitive semantic types used throughout the PRC-369 Kernel.
/// @dev Part of the immutable PRC-369 Kernel.
///
/// IMPORTANT:
/// This file contains only User Defined Value Types (UDVT).
/// No functions, structs, enums, storage or business logic are allowed.

/// @notice Unique identifier of a Position.
type PositionId is uint256;

/// @notice Monotonically increasing nonce associated with a Position.
type PositionNonce is uint64;

/// @notice Position generation identifier.
type Generation is uint64;

/// @notice Capability bitmask.
type CapabilityMask is uint256;

/// @notice Identifier of an Asset Adapter.
type AdapterId is bytes32;

/// @notice Identifier of a Position Family.
type PositionFamilyId is uint32;

/// @notice Identifier of a Position Class.
type PositionClassId is uint16;

/// @notice Identifier of a Position Version.
type VersionId is uint32;

/// @notice Identifier of a settlement operation.
type SettlementId is uint256;

/// @notice Identifier of a rights package.
type RightsId is uint256;
