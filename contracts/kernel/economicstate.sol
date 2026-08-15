// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";
import "./EconomicTypes.sol";

/// @title PRC-369 Economic State
/// @author MINTer
/// @notice Defines the canonical economic state represented by a Position.
/// @dev
/// This module defines semantic structure only.
///
/// It does NOT:
/// - Store state on-chain.
/// - Execute settlement.
/// - Transfer assets.
/// - Calculate market value.
/// - Define protocol-specific economics.
///
/// Concrete runtime modules are responsible for storing and updating
/// EconomicState values.

struct EconomicState {

    /// @notice Unique identifier of this economic state.
    EconomicStateId stateId;

    /// @notice Economic asset represented by the Position.
    EconomicAssetId assetId;

    /// @notice Unit in which the economic amount is expressed.
    EconomicUnitId unitId;

    /// @notice Quantity represented by the Position.
    EconomicAmount amount;

    /// @notice Decimal precision associated with the amount.
    EconomicScale scale;

    /// @notice Optional economic rights package.
    RightsId rightsId;

    /// @notice Settlement operation associated with this state.
    SettlementId settlementId;

    /// @notice Condition governing the economic state.
    EconomicConditionId conditionId;

    /// @notice Timestamp at which this state becomes effective.
    EconomicTimestamp effectiveAt;

    /// @notice Duration associated with the state.
    EconomicDuration duration;
}
