// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Version
/// @author MINTer
/// @notice Defines the canonical semantic version structure used throughout PRC-369.
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
/// This file defines the canonical semantic version model shared by all
/// PRC-369 compliant implementations.

//////////////////////////////////////////////////////////////
// VERSION
//////////////////////////////////////////////////////////////

/// @notice Canonical semantic version.
struct Version {
    uint16 major;
    uint16 minor;
    uint16 patch;
}
