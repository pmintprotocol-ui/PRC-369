// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Types.sol";

/// @title PRC-369 Kernel Events
/// @author MINTer
/// @notice Canonical events for the PRC-369 Kernel.
/// @dev
/// Part of the immutable PRC-369 Kernel.
///
/// DESIGN PRINCIPLES
/// - No storage
/// - No functions
/// - No structs
/// - No enums
/// - No errors
///
/// This file defines the canonical event language shared by all
/// PRC-369 compliant implementations.

//////////////////////////////////////////////////////////////
// POSITION EVENTS
//////////////////////////////////////////////////////////////

/// @notice Emitted when a Position is registered.
event PositionRegistered(
    PositionId indexed positionId
);

/// @notice Emitted when a Position is archived.
event PositionArchived(
    PositionId indexed positionId
);

//////////////////////////////////////////////////////////////
// POSITION STATE EVENTS
//////////////////////////////////////////////////////////////

/// @notice Emitted whenever a Position changes its lifecycle state.
event PositionStateChanged(
    PositionId indexed positionId,
    PositionStateId previousState,
    PositionStateId newState
);

//////////////////////////////////////////////////////////////
// REGISTRY EVENTS
//////////////////////////////////////////////////////////////

/// @notice Emitted when a Protocol is registered.
event ProtocolRegistered(
    ProtocolId indexed protocol
);

/// @notice Emitted when an Asset Adapter is registered.
event AdapterRegistered(
    AdapterId indexed adapter
);

//////////////////////////////////////////////////////////////
// CAPABILITY EVENTS
//////////////////////////////////////////////////////////////

/// @notice Emitted when a capability is enabled.
event CapabilityEnabled(
    PositionId indexed positionId,
    CapabilityMask indexed capability
);

/// @notice Emitted when a capability is disabled.
event CapabilityDisabled(
    PositionId indexed positionId,
    CapabilityMask indexed capability
);

//////////////////////////////////////////////////////////////
// LIFECYCLE EVENTS
//////////////////////////////////////////////////////////////

/// @notice Emitted when a Position becomes active.
event PositionActivated(
    PositionId indexed positionId
);

/// @notice Emitted when a Position is locked.
event PositionLocked(
    PositionId indexed positionId
);

/// @notice Emitted when a Position is unlocked.
event PositionUnlocked(
    PositionId indexed positionId
);

/// @notice Emitted when a Position is redeemed.
event PositionRedeemed(
    PositionId indexed positionId
);

//////////////////////////////////////////////////////////////
// SETTLEMENT EVENTS
//////////////////////////////////////////////////////////////

/// @notice Emitted when a Position is settled.
event PositionSettled(
    PositionId indexed positionId,
    SettlementId settlementId
);
