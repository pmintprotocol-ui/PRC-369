// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Position Types
/// @author MINTer
/// @notice Defines the canonical Position Classes of the PRC-369 Kernel.
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
/// This library defines the canonical Position Classes shared by
/// all PRC-369 compliant implementations.
///
/// Position Families are implementation-specific and MUST NOT be
/// defined here.

library PositionTypes {

    //////////////////////////////////////////////////////////////
    // KERNEL POSITION CLASSES
    //////////////////////////////////////////////////////////////

    /// @notice Reserve Position.
    PositionClassId internal constant RESERVE =
        PositionClassId.wrap(1);

    /// @notice Vault Position.
    PositionClassId internal constant VAULT =
        PositionClassId.wrap(2);

    /// @notice Liquidity Pool Position.
    PositionClassId internal constant POOL =
        PositionClassId.wrap(3);

    /// @notice Collateral Position.
    PositionClassId internal constant COLLATERAL =
        PositionClassId.wrap(4);

    /// @notice Debt Position.
    PositionClassId internal constant DEBT =
        PositionClassId.wrap(5);

    /// @notice Derivative Position.
    PositionClassId internal constant DERIVATIVE =
        PositionClassId.wrap(6);

    /// @notice Synthetic Position.
    PositionClassId internal constant SYNTHETIC =
        PositionClassId.wrap(7);

    /// @notice Receipt Position.
    PositionClassId internal constant RECEIPT =
        PositionClassId.wrap(8);
}
