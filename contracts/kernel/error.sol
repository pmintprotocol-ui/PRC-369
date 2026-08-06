// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Kernel Errors
/// @author MINTer
/// @notice Canonical custom errors for the PRC-369 Kernel.
/// @dev
/// Part of the immutable PRC-369 Kernel.
///
/// DESIGN PRINCIPLES
/// - No storage
/// - No functions
/// - No structs
/// - No enums
/// - No events
///
/// This file defines the canonical language of errors shared by all
/// PRC-369 compliant implementations.

//////////////////////////////////////////////////////////////
// GENERAL ERRORS
//////////////////////////////////////////////////////////////

/// @notice A required address is the zero address.
error ZeroAddress();

/// @notice A required value is zero.
error ZeroValue();

/// @notice One or more parameters are invalid.
error InvalidParameter();

/// @notice The requested operation is not supported.
error UnsupportedOperation();

/// @notice Caller is not authorized.
error Unauthorized();

//////////////////////////////////////////////////////////////
// IDENTITY ERRORS
//////////////////////////////////////////////////////////////

/// @notice Invalid protocol identifier.
error InvalidProtocol();

/// @notice Invalid position class.
error InvalidPositionClass();

/// @notice Invalid position family.
error InvalidPositionFamily();

/// @notice Invalid version identifier.
error InvalidVersion();

//////////////////////////////////////////////////////////////
// POSITION ERRORS
//////////////////////////////////////////////////////////////

/// @notice Position does not exist.
error PositionNotFound();

/// @notice Position already exists.
error PositionAlreadyExists();

/// @notice Position has already been registered.
error PositionAlreadyRegistered();

/// @notice Invalid position state.
error InvalidPositionState();

//////////////////////////////////////////////////////////////
// CAPABILITY ERRORS
//////////////////////////////////////////////////////////////

/// @notice Capability is not supported.
error CapabilityNotSupported();

/// @notice Capability is already enabled.
error CapabilityAlreadyEnabled();

/// @notice Capability is already disabled.
error CapabilityAlreadyDisabled();

//////////////////////////////////////////////////////////////
// REGISTRY ERRORS
//////////////////////////////////////////////////////////////

/// @notice Protocol is already registered.
error ProtocolAlreadyRegistered();

/// @notice Protocol is not registered.
error ProtocolNotRegistered();

/// @notice Adapter is not registered.
error AdapterNotRegistered();

//////////////////////////////////////////////////////////////
// ADAPTER ERRORS
//////////////////////////////////////////////////////////////

/// @notice Invalid adapter.
error InvalidAdapter();

/// @notice Adapter already registered.
error AdapterAlreadyRegistered();

/// @notice Adapter is not compatible.
error AdapterNotCompatible();

//////////////////////////////////////////////////////////////
// SETTLEMENT ERRORS
//////////////////////////////////////////////////////////////

/// @notice Settlement is not allowed.
error SettlementNotAllowed();

/// @notice Settlement has already been executed.
error SettlementAlreadyExecuted();

/// @notice Settlement has expired.
error SettlementExpired();

//////////////////////////////////////////////////////////////
// INTERNAL ERRORS
//////////////////////////////////////////////////////////////

/// @notice Internal kernel invariant violated.
error KernelInvariantViolation();

/// @notice Unexpected internal state.
error UnexpectedState();
