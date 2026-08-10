// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/Events.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Position Lifecycle
/// @author MINTer
/// @notice Controls canonical lifecycle transitions of PRC-369 Positions.
/// @dev
/// Runtime component responsible for validating and executing lifecycle
/// transitions while delegating Position state storage to PositionRegistry.
///
/// The Lifecycle module does NOT:
/// - Define Position identity.
/// - Store Position definitions.
/// - Execute economic settlements.
/// - Interact with Asset Adapters.
/// - Modify Kernel semantic definitions.
///
/// It only controls permitted lifecycle transitions.
contract PositionLifecycle {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Registry used as the authoritative Position state store.
    PositionRegistry public immutable registry;

    /// @notice Authority allowed to execute lifecycle transitions.
    address public immutable lifecycleAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the lifecycle controller.
    /// @param registryAddress Address of the Position Registry.
    /// @param authority Address authorized to execute transitions.
    constructor(
        address registryAddress,
        address authority
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registry = PositionRegistry(registryAddress);
        lifecycleAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // ACTIVATION
    //////////////////////////////////////////////////////////////

    /// @notice Activates a newly created Position.
    /// @dev Valid transition: CREATED -> ACTIVE.
    /// @param positionId Position identifier.
    function activate(
        PositionId positionId
    )
        external
    {
        _authorize();
        _transition(
            positionId,
            PositionStates.CREATED,
            PositionStates.ACTIVE
        );

        emit PositionActivated(positionId);
    }

    //////////////////////////////////////////////////////////////
    // LOCK
    //////////////////////////////////////////////////////////////

    /// @notice Locks an active Position.
    /// @dev Valid transition: ACTIVE -> LOCKED.
    /// @param positionId Position identifier.
    function lock(
        PositionId positionId
    )
        external
    {
        _authorize();
        _transition(
            positionId,
            PositionStates.ACTIVE,
            PositionStates.LOCKED
        );

        emit PositionLocked(positionId);
    }

    //////////////////////////////////////////////////////////////
    // UNLOCK
    //////////////////////////////////////////////////////////////

    /// @notice Unlocks a locked Position.
    /// @dev Valid transition: LOCKED -> ACTIVE.
    /// @param positionId Position identifier.
    function unlock(
        PositionId positionId
    )
        external
    {
        _authorize();
        _transition(
            positionId,
            PositionStates.LOCKED,
            PositionStates.ACTIVE
        );

        emit PositionUnlocked(positionId);
    }

    //////////////////////////////////////////////////////////////
    // REDEEM
    //////////////////////////////////////////////////////////////

    /// @notice Redeems an active Position.
    /// @dev Valid transition: ACTIVE -> REDEEMED.
    /// @param positionId Position identifier.
    function redeem(
        PositionId positionId
    )
        external
    {
        _authorize();
        _transition(
            positionId,
            PositionStates.ACTIVE,
            PositionStates.REDEEMED
        );

        emit PositionRedeemed(positionId);
    }

    //////////////////////////////////////////////////////////////
    // SETTLE
    //////////////////////////////////////////////////////////////

    /// @notice Settles an active Position.
    /// @dev Valid transition: ACTIVE -> SETTLED.
    /// @param positionId Position identifier.
    function settle(
        PositionId positionId
    )
        external
    {
        _authorize();
        _transition(
            positionId,
            PositionStates.ACTIVE,
            PositionStates.SETTLED
        );

        emit PositionSettled(
            positionId,
            SettlementId.wrap(0)
        );
    }

    //////////////////////////////////////////////////////////////
    // ARCHIVE
    //////////////////////////////////////////////////////////////

    /// @notice Archives a terminal Position.
    /// @dev Valid transitions:
    ///      REDEEMED -> ARCHIVED
    ///      SETTLED  -> ARCHIVED
    /// @param positionId Position identifier.
    function archive(
        PositionId positionId
    )
        external
    {
        _authorize();

        PositionRuntime memory current =
            registry.getPositionRuntime(positionId);

        PositionStateId currentState =
            current.stateId;

        if (
            PositionStateId.unwrap(currentState) !=
                PositionStateId.unwrap(PositionStates.REDEEMED)
            &&
            PositionStateId.unwrap(currentState) !=
                PositionStateId.unwrap(PositionStates.SETTLED)
        ) {
            revert InvalidPositionState();
        }

        current.stateId = PositionStates.ARCHIVED;
        current.nonce = PositionNonce.wrap(
            PositionNonce.unwrap(current.nonce) + 1
        );

        registry.updateRuntime(
            positionId,
            current
        );

        emit PositionArchived(positionId);
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL TRANSITION
    //////////////////////////////////////////////////////////////

    /// @notice Executes a validated lifecycle transition.
    /// @param positionId Position identifier.
    /// @param expectedState Required current state.
    /// @param newState New lifecycle state.
    function _transition(
        PositionId positionId,
        PositionStateId expectedState,
        PositionStateId newState
    )
        internal
    {
        PositionRuntime memory current =
            registry.getPositionRuntime(positionId);

        if (
            PositionStateId.unwrap(current.stateId) !=
            PositionStateId.unwrap(expectedState)
        ) {
            revert InvalidPositionState();
        }

        current.stateId = newState;

        current.nonce = PositionNonce.wrap(
            PositionNonce.unwrap(current.nonce) + 1
        );

        registry.updateRuntime(
            positionId,
            current
        );
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates lifecycle authority.
    function _authorize()
        internal
        view
    {
        if (msg.sender != lifecycleAuthority) {
            revert Unauthorized();
        }
    }
}
