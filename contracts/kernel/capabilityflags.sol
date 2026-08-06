// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Capability Flags
/// @author MINTer
/// @notice Defines the canonical capability flags used by PRC-369.
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
/// This library defines the canonical capability bit flags shared by
/// all PRC-369 compliant implementations.
///
/// Each capability occupies a unique bit within CapabilityMask.

library CapabilityFlags {

    //////////////////////////////////////////////////////////////
    // TRANSFER CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position ownership can be transferred.
    CapabilityMask internal constant TRANSFERABLE =
        CapabilityMask.wrap(1 << 0);

    //////////////////////////////////////////////////////////////
    // COMPOSITION CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position can be split into multiple Positions.
    CapabilityMask internal constant SPLITTABLE =
        CapabilityMask.wrap(1 << 1);

    /// @notice Multiple Positions can be merged.
    CapabilityMask internal constant MERGEABLE =
        CapabilityMask.wrap(1 << 2);

    /// @notice Position can compose with other Positions.
    CapabilityMask internal constant COMPOSABLE =
        CapabilityMask.wrap(1 << 3);

    //////////////////////////////////////////////////////////////
    // LIFECYCLE CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position can be locked.
    CapabilityMask internal constant LOCKABLE =
        CapabilityMask.wrap(1 << 4);

    /// @notice Position can be redeemed.
    CapabilityMask internal constant REDEEMABLE =
        CapabilityMask.wrap(1 << 5);

    //////////////////////////////////////////////////////////////
    // SETTLEMENT CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position supports settlement.
    CapabilityMask internal constant SETTLABLE =
        CapabilityMask.wrap(1 << 6);

    //////////////////////////////////////////////////////////////
    // EVOLUTION CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position definition can evolve.
    CapabilityMask internal constant UPGRADABLE =
        CapabilityMask.wrap(1 << 7);
}
