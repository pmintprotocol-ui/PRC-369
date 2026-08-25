// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Position State Manager
/// @author MINTer
/// @notice Manages the mutable lifecycle state of PRC-369 Positions.
/// @dev
/// Runtime component responsible for controlling Position lifecycle state.
///
/// It does NOT:
/// - Define Position identity.
/// - Store Position identity.
/// - Execute economic settlement.
/// - Transfer assets.
/// - Modify EconomicState.
/// - Define Position capabilities.
///
/// PositionRegistry remains authoritative for Position runtime storage.
/// PositionStates defines the canonical Position state vocabulary.
///
/// This contract defines controlled Position state transitions.

contract PositionStateManager {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Position Registry.
    PositionRegistry public immutable registry;

    /// @notice Authority allowed to modify Position state.
    address public immutable stateAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

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
        stateAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // INITIALIZE
    //////////////////////////////////////////////////////////////

    /// @notice Returns the current Position state.
    /// @param positionId Position identifier.
    /// @return state Current Position state.
    function getState(
        PositionId positionId
    )
        external
        view
        returns (
            PositionStateId state
        )
    {
        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        PositionRuntime memory runtime =
            registry.getPositionRuntime(positionId);

        return runtime.stateId;
    }

    //////////////////////////////////////////////////////////////
    // STATE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position is currently in a state.
    /// @param positionId Position identifier.
    /// @param state State to check.
    /// @return matches True when the state matches.
    function isState(
        PositionId positionId,
        PositionStateId state
    )
        external
        view
        returns (
            bool matches
        )
    {
        if (!registry.positionExists(positionId)) {
            return false;
        }

        PositionRuntime memory runtime =
            registry.getPositionRuntime(positionId);

        return
            PositionStateId.unwrap(runtime.stateId)
            ==
            PositionStateId.unwrap(state);
    }

    //////////////////////////////////////////////////////////////
    // TRANSITION
    //////////////////////////////////////////////////////////////

    /// @notice Transitions a Position to a new lifecycle state.
    /// @param positionId Position identifier.
    /// @param newState New Position state.
    function transition(
        PositionId positionId,
        PositionStateId newState
    )
        external
    {
        _authorize();

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        if (
            PositionStateId.unwrap(newState) == 0
        ) {
            revert ZeroValue();
        }

        PositionRuntime memory runtime =
            registry.getPositionRuntime(positionId);

        PositionStateId currentState =
            runtime.stateId;

        if (
            !_isValidTransition(
                currentState,
                newState
            )
        ) {
            revert InvalidStateTransition();
        }

        runtime.stateId = newState;

        runtime.nonce = PositionNonce.wrap(
            PositionNonce.unwrap(runtime.nonce) + 1
        );

        registry.updateRuntime(
            positionId,
            runtime
        );
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE TRANSITION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position state transition is valid.
    /// @param currentState Current Position state.
    /// @param newState Requested Position state.
    /// @return valid True when transition is permitted.
    function isValidTransition(
        PositionStateId currentState,
        PositionStateId newState
    )
        external
        pure
        returns (
            bool valid
        )
    {
        return _isValidTransition(
            currentState,
            newState
        );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL TRANSITION RULES
    //////////////////////////////////////////////////////////////

    function _isValidTransition(
        PositionStateId currentState,
        PositionStateId newState
    )
        internal
        pure
        returns (bool)
    {
        uint256 current =
            PositionStateId.unwrap(
                currentState
            );

        uint256 next =
            PositionStateId.unwrap(
                newState
            );

        //////////////////////////////////////////////////////////
        // CREATED → ACTIVE
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.CREATED
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.ACTIVE
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // ACTIVE → LOCKED
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.ACTIVE
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.LOCKED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // LOCKED → ACTIVE
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.LOCKED
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.ACTIVE
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // ACTIVE → REDEEMED
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.ACTIVE
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.REDEEMED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // ACTIVE → SETTLED
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.ACTIVE
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.SETTLED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // REDEEMED → ARCHIVED
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.REDEEMED
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.ARCHIVED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // SETTLED → ARCHIVED
        //////////////////////////////////////////////////////////

        if (
            current ==
            PositionStateId.unwrap(
                PositionStates.SETTLED
            )
            &&
            next ==
            PositionStateId.unwrap(
                PositionStates.ARCHIVED
            )
        ) {
            return true;
        }

        return false;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (
            msg.sender != stateAuthority
        ) {
            revert Unauthorized();
        }
    }
}
