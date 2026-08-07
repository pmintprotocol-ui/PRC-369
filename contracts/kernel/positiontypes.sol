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
/// Position Classes describe the economic nature of a Position.
///
/// Position Families are implementation-specific and MUST NOT be
/// defined here.
///
/// Examples:
/// - Class: RESERVE
///   Family: MCReserve, DCReserve, HCReserve...
///
/// - Class: VAULT
///   Family: TreasuryVault, FeeVault...
library PositionTypes {

    //////////////////////////////////////////////////////////////
    // CAPITAL POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Capital reserve Position.
    PositionClassId internal constant RESERVE =
        PositionClassId.wrap(1);

    /// @notice Vault Position.
    PositionClassId internal constant VAULT =
        PositionClassId.wrap(2);

    //////////////////////////////////////////////////////////////
    // MARKET POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Liquidity Pool Position.
    PositionClassId internal constant POOL =
        PositionClassId.wrap(3);

    /// @notice Collateral Position.
    PositionClassId internal constant COLLATERAL =
        PositionClassId.wrap(4);

    /// @notice Debt Position.
    PositionClassId internal constant DEBT =
        PositionClassId.wrap(5);

    //////////////////////////////////////////////////////////////
    // DERIVATIVE POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Generic Derivative Position.
    PositionClassId internal constant DERIVATIVE =
        PositionClassId.wrap(6);

    /// @notice Synthetic Asset Position.
    PositionClassId internal constant SYNTHETIC =
        PositionClassId.wrap(7);

    /// @notice Financial Option Position.
    PositionClassId internal constant OPTION =
        PositionClassId.wrap(8);

    /// @notice Futures Contract Position.
    PositionClassId internal constant FUTURE =
        PositionClassId.wrap(9);

    //////////////////////////////////////////////////////////////
    // CERTIFICATE POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Receipt Position.
    PositionClassId internal constant RECEIPT =
        PositionClassId.wrap(10);

    /// @notice Bond Position.
    PositionClassId internal constant BOND =
        PositionClassId.wrap(11);

    //////////////////////////////////////////////////////////////
    // CONTROL POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Escrow Position.
    PositionClassId internal constant ESCROW =
        PositionClassId.wrap(12);

    /// @notice Governance Position.
    PositionClassId internal constant GOVERNANCE =
        PositionClassId.wrap(13);

    //////////////////////////////////////////////////////////////
    // PRODUCTIVITY POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Staking Position.
    PositionClassId internal constant STAKING =
        PositionClassId.wrap(14);

}
