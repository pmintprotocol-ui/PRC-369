// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionStates.sol";
import "./CompositionOperationRegistry.sol";

/// @title PRC-369 Composition State Manager
/// @author MINTer
/// @notice Manages the mutable lifecycle state of PRC-369 Compositions.
/// @dev
/// Runtime component responsible for controlling Composition lifecycle.
///
/// It does NOT:
/// - Execute economic composition.
/// - Modify EconomicState.
/// - Modify Position identity.
/// - Transfer assets.
/// - Execute settlement.
///
/// CompositionStates defines the canonical state vocabulary.
/// This contract defines the permitted runtime transitions.

contract CompositionStateManager {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Composition Operation Registry.
    CompositionOperationRegistry public immutable operationRegistry;

    /// @notice Authority allowed to modify Composition state.
    address public immutable stateAuthority;

    /// @notice Current lifecycle state of each Composition.
    mapping(CompositionId => PositionStateId)
        private _states;

    /// @notice Tracks whether a Composition state was initialized.
    mapping(CompositionId => bool)
        private _initialized;


    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address operationRegistryAddress,
        address authority
    ) {
        if (
            operationRegistryAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            authority == address(0)
        ) {
            revert ZeroAddress();
        }

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        stateAuthority = authority;
    }


    //////////////////////////////////////////////////////////////
    // INITIALIZE
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the lifecycle of a Composition.
    /// @param compositionId Composition identifier.
    function initializeState(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        _validateComposition(
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
    /// @param newState New lifecycle state.
    function transition(
        CompositionId compositionId,
        PositionStateId newState
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
            PositionStateId.unwrap(newState)
            == 0
        ) {
            revert ZeroValue();
        }

        PositionStateId currentState =
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

    /// @notice Returns the current Composition state.
    /// @param compositionId Composition identifier.
    /// @return state Current lifecycle state.
    function getState(
        CompositionId compositionId
    )
        external
        view
        returns (
            PositionStateId state
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

    /// @notice Returns whether a Composition state is initialized.
    /// @param compositionId Composition identifier.
    /// @return initialized True when initialized.
    function isInitialized(
        CompositionId compositionId
    )
        external
        view
        returns (bool initialized)
    {
        return _initialized[compositionId];
    }


    //////////////////////////////////////////////////////////////
    // STATE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition is currently in a state.
    /// @param compositionId Composition identifier.
    /// @param state State to check.
    /// @return matches True when the state matches.
    function isState(
        CompositionId compositionId,
        PositionStateId state
    )
        external
        view
        returns (bool matches)
    {
        if (
            !_initialized[compositionId]
        ) {
            return false;
        }

        return
            PositionStateId.unwrap(
                _states[compositionId]
            )
            ==
            PositionStateId.unwrap(
                state
            );
    }


    //////////////////////////////////////////////////////////////
    // TRANSITION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a state transition is valid.
    /// @param currentState Current lifecycle state.
    /// @param newState Requested lifecycle state.
    /// @return valid True when transition is permitted.
    function isValidTransition(
        PositionStateId currentState,
        PositionStateId newState
    )
        external
        pure
        returns (bool valid)
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
        // CREATED → CONFIGURING
        //////////////////////////////////////////////////////////

        if (
            current
            ==
            PositionStateId.unwrap(
                CompositionStates.CREATED
            )
            &&
            next
            ==
            PositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // CONFIGURING → READY
        //////////////////////////////////////////////////////////

        if (
            current
            ==
            PositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
            &&
            next
            ==
            PositionStateId.unwrap(
                CompositionStates.READY
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // CONFIGURING → CANCELLED
        //////////////////////////////////////////////////////////

        if (
            current
            ==
            PositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
            &&
            next
            ==
            PositionStateId.unwrap(
                CompositionStates.CANCELLED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // READY → EXECUTING
        //////////////////////////////////////////////////////////

        if (
            current
            ==
            PositionStateId.unwrap(
                CompositionStates.READY
            )
            &&
            next
            ==
            PositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // EXECUTING → COMPLETED
        //////////////////////////////////////////////////////////

        if (
            current
            ==
            PositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
            &&
            next
            ==
            PositionStateId.unwrap(
                CompositionStates.COMPLETED
            )
        ) {
            return true;
        }

        //////////////////////////////////////////////////////////
        // EXECUTING → FAILED
        //////////////////////////////////////////////////////////

        if (
            current
            ==
            PositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
            &&
            next
            ==
            PositionStateId.unwrap(
                CompositionStates.FAILED
            )
        ) {
            return true;
        }

        return false;
    }


    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSITION
    //////////////////////////////////////////////////////////////

    function _validateComposition(
        CompositionId compositionId
    )
        internal
        view
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (
            !operationRegistry.isActive(
                compositionId
            )
        ) {
            revert UnsupportedOperation();
        }
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
