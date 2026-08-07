// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Semantic Version
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
/// This file defines the canonical Semantic Version (SemVer) model
/// shared by all PRC-369 compliant implementations.
///
/// Semantic versions describe protocol compatibility rather than
/// implementation releases.
///
/// The version model follows the MAJOR.MINOR.PATCH convention:
///
/// MAJOR
/// - Breaking semantic changes.
/// - May introduce incompatibilities.
///
/// MINOR
/// - Backward-compatible feature additions.
///
/// PATCH
/// - Backward-compatible fixes or clarifications.
///
/// The Runtime may use this structure to validate compatibility
/// between Positions, Adapters and protocol implementations.

//////////////////////////////////////////////////////////////
// VERSION
//////////////////////////////////////////////////////////////

/// @notice Canonical semantic version.
///
/// @dev
/// Represents the semantic compatibility version of a PRC-369
/// component or Position definition.
struct Version {

    /// @notice Major semantic version.
    uint16 major;

    /// @notice Minor semantic version.
    uint16 minor;

    /// @notice Patch semantic version.
    uint16 patch;

}
