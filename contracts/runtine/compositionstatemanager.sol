// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionStates.sol";
import "./CompositionOperationRegistry.sol";

/// @title PRC-369 Composition State Manager
/// @author MINTer
/// @notice Manages the lifecycle state of PRC-369 Compositions.
/// @dev
/// This contract manages Composition lifecycle independently
/// from Position lifecycle.
///
/// It does NOT:
/// - Modify Position identity.
/// - Modify Position Runtime.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Execute settlement.
/// - Execute economic composition.
///
/// CompositionOperationRegistry remains authoritative for
/// available Composition operations.
contract CompositionStateManager {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Composition Operation Registry.
    CompositionOperationRegistry public immutable operationRegistry;

    /// @notice Authority allowed to modify Composition state.
    address public immutable stateAuthority;

    /// @notice Current lifecycle state of each Composition.
    ///
    /// CompositionStates currently uses PositionStateId as the
    /// canonical state identifier type.
    mapping(CompositionId => PositionStateId)
        private _states;

    /// @notice Tracks whether a Composition has been initialized.
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

    /// @notice Initializes a Composition.
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

    /// @notice Transitions a Composition to a new state.
    /// @param compositionId Composition identifier.
    /// @param newState New Composition state.
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

    /// @notice Returns whether a Composition is initialized.
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

    /// @notice Checks whether a Composition is in a state.
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

        // CREATED -> CONFIGURING
        if (
            current ==
            PositionStateId.unwrap(
                CompositionStates.CREATED
            )
            &&
            next ==
            PositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
        ) {
            return true;
        }

        // CONFIGURING -> READY
        if (
            current ==
            PositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
            &&
            next ==
            PositionStateId.unwrap(
                CompositionStates.READY
            )
        ) {
            return true;
        }

        // CONFIGURING -> CANCELLED
        if (
            current ==
            PositionStateId.unwrap(
                CompositionStates.CONFIGURING
            )
            &&
            next ==
            PositionStateId.unwrap(
                CompositionStates.CANCELLED
            )
        ) {
            return true;
        }

        // READY -> EXECUTING
        if (
            current ==
            PositionStateId.unwrap(
                CompositionStates.READY
            )
            &&
            next ==
            PositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
        ) {
            return true;
        }

        // EXECUTING -> COMPLETED
        if (
            current ==
            PositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
            &&
            next ==
            PositionStateId.unwrap(
                CompositionStates.COMPLETED
            )
        ) {
            return true;
        }

        // EXECUTING -> FAILED
        if (
            current ==
            PositionStateId.unwrap(
                CompositionStates.EXECUTING
            )
            &&
            next ==
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
