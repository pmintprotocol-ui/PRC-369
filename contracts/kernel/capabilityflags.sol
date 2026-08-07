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

    /// @notice Position ownership may be transferred.
    CapabilityMask internal constant TRANSFERABLE =
        CapabilityMask.wrap(1 << 0);

    //////////////////////////////////////////////////////////////
    // COMPOSITION CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position may be split into multiple Positions.
    CapabilityMask internal constant SPLITTABLE =
        CapabilityMask.wrap(1 << 1);

    /// @notice Multiple Positions may merge into one Position.
    CapabilityMask internal constant MERGEABLE =
        CapabilityMask.wrap(1 << 2);

    /// @notice Position may compose with other Positions.
    CapabilityMask internal constant COMPOSABLE =
        CapabilityMask.wrap(1 << 3);

    //////////////////////////////////////////////////////////////
    // LIFECYCLE CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position may be locked.
    CapabilityMask internal constant LOCKABLE =
        CapabilityMask.wrap(1 << 4);

    /// @notice Position may be redeemed.
    CapabilityMask internal constant REDEEMABLE =
        CapabilityMask.wrap(1 << 5);

    //////////////////////////////////////////////////////////////
    // SETTLEMENT CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position supports settlement operations.
    CapabilityMask internal constant SETTLABLE =
        CapabilityMask.wrap(1 << 6);

    //////////////////////////////////////////////////////////////
    // EVOLUTION CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position definition may evolve.
    CapabilityMask internal constant UPGRADABLE =
        CapabilityMask.wrap(1 << 7);

    //////////////////////////////////////////////////////////////
    // FINANCIAL CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position may be pledged as collateral.
    CapabilityMask internal constant COLLATERALIZABLE =
        CapabilityMask.wrap(1 << 8);

    /// @notice Position may be leased.
    CapabilityMask internal constant LEASABLE =
        CapabilityMask.wrap(1 << 9);

    /// @notice Position may be fractionalized.
    CapabilityMask internal constant FRACTIONALIZABLE =
        CapabilityMask.wrap(1 << 10);

    //////////////////////////////////////////////////////////////
    // RIGHTS CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Rights associated with the Position may be delegated.
    CapabilityMask internal constant DELEGATABLE =
        CapabilityMask.wrap(1 << 11);

    /// @notice Rights associated with the Position may be inherited.
    CapabilityMask internal constant INHERITABLE =
        CapabilityMask.wrap(1 << 12);

    //////////////////////////////////////////////////////////////
    // REPRESENTATION CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Position may be wrapped into another standardized representation.
    CapabilityMask internal constant WRAPPABLE =
        CapabilityMask.wrap(1 << 13);

}
