// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Economic Types
/// @author MINTer
/// @notice Defines primitive semantic types used by PRC-369 Economic State.
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
/// Economic modules build upon these primitive semantic types.

//////////////////////////////////////////////////////////////
// ECONOMIC IDENTIFIERS
//////////////////////////////////////////////////////////////

/// @notice Unique identifier of an economic asset namespace.
type EconomicAssetId is bytes32;

/// @notice Unique identifier of an economic unit.
type EconomicUnitId is bytes32;

/// @notice Unique identifier of an economic state.
type EconomicStateId is uint256;

/// @notice Unique identifier of an economic condition.
type EconomicConditionId is bytes32;


//////////////////////////////////////////////////////////////
// ECONOMIC VALUE TYPES
//////////////////////////////////////////////////////////////

/// @notice Quantitative economic value.
type EconomicAmount is uint256;

/// @notice Economic precision or decimal scale.
type EconomicScale is uint8;


//////////////////////////////////////////////////////////////
// ECONOMIC TIME TYPES
//////////////////////////////////////////////////////////////

/// @notice Timestamp associated with an economic condition.
type EconomicTimestamp is uint64;

/// @notice Duration associated with an economic condition.
type EconomicDuration is uint64;
