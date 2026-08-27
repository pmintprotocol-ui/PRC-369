// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionStates.sol";
import "../kernel/Errors.sol";

/// @title PRC-369 Composition State Manager
/// @author MINTer
/// @notice Manages the canonical lifecycle state of PRC-369 Compositions.
/// @dev
/// This Runtime component manages Composition lifecycle independently
/// from Position lifecycle.
///
/// It does NOT:
/// - Modify Position identity.
/// - Modify Position Runtime.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Execute settlement.
/// - Execute economic composition.
/// - Define Composition identity.
///
/// CompositionStateManager is authoritative only for the lifecycle
/// state of a Composition.
///
/// Composition identifiers and Composition state identifiers are
/// independent from Position identifiers and Position states.

contract CompositionStateManager {

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage Composition states.
    address public immutable stateAuthority;

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Current lifecycle state of each Composition.
    mapping(CompositionId => CompositionStateId)
        private _states;

    /// @notice Tracks whether a Composition has been initialized.
    mapping(CompositionId => bool)
        private _initialized;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition State Manager.
    /// @param authority Authority allowed to manage Composition state.
    constructor(
        address authority
    ) {
        if (
            authority == address(0)
        ) {
            revert ZeroAddress();
        }

        stateAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // INITIALIZE
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the lifecycle state of a Composition.
    /// @dev New Compositions always begin in CREATED state.
    /// @param compositionId Composition identifier.
    function initializeState(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        if (
            _initialized[compositionId]
        ) {
            revert PositionAlreadyRegistered();
        }

        _states[compositionId] =
            CompositionStates.CREATED;

        _initialized[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // TRANSITION
    //////////////////////////////////////////////////////////////

    /// @notice Transitions a Composition to a new lifecycle state.
    /// @param compositionId Composition identifier.
    /// @param newState New Composition lifecycle state.
    function transition(
        CompositionId compositionId,
        CompositionStateId newState
    )
        external
    {
        _authorize();

        if (
            !_initialized[compositionId]
        ) {
            revert PositionNotFound();
        }

        if (
            CompositionStateId.unwrap(newState)
            == 0
        ) {
            revert ZeroValue();
        }

        CompositionStateId currentState =
            _states[compositionId];

        if (
            !_isValidTransition(
                currentState,
                newState
            )
        ) {
            revert InvalidStateTransition();
        }

        _states[compositionId] =
            newState;
    }

    //////////////////////////////////////////////////////////////
    // READ STATE
    //////////////////////////////////////////////////////////////

    /// @notice Returns the current lifecycle state.
    /// @param compositionId Composition identifier.
    /// @return state Current Composition state.
    function getState(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionStateId state
        )
    {
        if (
            !_initialized[compositionId]
        ) {
            revert PositionNotFound();
        }

        return _states[compositionId];
    }

    //////////////////////////////////////////////////////////////
    // INITIALIZATION STATUS
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition has been initialized.
    /// @param compositionId Composition identifier.
    /// @return initialized True if initialized.
    function isInitialized(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool initialized
        )
    {
        return _initialized[compositionId];
    }

    //////////////////////////////////////////////////////////////
    // STATE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition is currently in a state.
    /// @param compositionId Composition identifier.
    /// @param state State being checked.
    /// @return matches True when the states match.
    function isState(
        CompositionId compositionId,
        CompositionStateId state
    )
        external
        view
        returns (
            bool matches
        )
    {
        if (
            !_initialized[compositionId]
        ) {
            return false;
        }

        return
            CompositionStateId.unwrap(
                _states[compositionId]
            )
            ==
            CompositionStateId.unwrap(
                state
            );
    }

    //////////////////////////////////////////////////////////////
    // TRANSITION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition state transition is valid.
    /// @param currentState Current state.
    /// @param newState Proposed new state.
    /// @return valid True when the transition is permitted.
    function isValidTransition(
        CompositionStateId currentState,
        CompositionStateId newState
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

    /// @dev Canonical Composition lifecycle transitions.
    ///
    /// CREATED
    ///    |
    ///    v
    /// CONFIGURING
    ///    |
    ///    v
    /// READY
    ///    |
    ///    v
    /// EXECUTING
    ///   / \
    ///  v   v
    /// COMPLETED  FAILED
    ///
    /// CONFIGURING -> CANCELLED
    function _isValidTransition(
        CompositionStateId currentState,
        CompositionStateId newState
    )
        internal
        pure
        returns (
            bool
        )
    {
        uint256 current =
            CompositionStateId.unwrap(
                currentState
            );

        uint256 next =
            CompositionStateId.unwrap(
                newState
            );

        //////////////////////////////////////////////////////////
        // CREATED -> CONFIGURING
        //////////////////////////////////////////////////////////

        if (
            current ==
            CompositionStateId.unwrap(
                CompositionStates.CREATED
            )
            &&
            next ==
            CompositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // CONFIGURING -> READY
        //////////////////////////////////////////////////////////

        if (
            current ==
            CompositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
            &&
            next ==
            CompositionStateId.unwrap(
                CompositionStates.READY
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // CONFIGURING -> CANCELLED
        //////////////////////////////////////////////////////////

        if (
            current ==
            CompositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
            &&
            next ==
            CompositionStateId.unwrap(
                CompositionStates.CANCELLED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // READY -> EXECUTING
        //////////////////////////////////////////////////////////

        if (
            current ==
            CompositionStateId.unwrap(
                CompositionStates.READY
            )
            &&
            next ==
            CompositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // EXECUTING -> COMPLETED
        //////////////////////////////////////////////////////////

        if (
            current ==
            CompositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
            &&
            next ==
            CompositionStateId.unwrap(
                CompositionStates.COMPLETED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // EXECUTING -> FAILED
        //////////////////////////////////////////////////////////

        if (
            current ==
            CompositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
            &&
            next ==
            CompositionStateId.unwrap(
                CompositionStates.FAILED
            )
        ) {
            return true;
        }

        return false;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSITION ID
    //////////////////////////////////////////////////////////////

    function _validateCompositionId(
        CompositionId compositionId
    )
        internal
        pure
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Composition State Manager authority.
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
