// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/CompositionStates.sol";
import "../kernel/Errors.sol";

import "./CompositionValidationManager.sol";
import "./CompositionStateManager.sol";
import "./CompositionOperationRegistry.sol";

/// @title PRC-369 Composition Execution Manager
/// @author MINTer
/// @notice Coordinates the execution lifecycle of a validated
///         PRC-369 Composition.
/// @dev
/// This contract is an execution coordination layer only.
///
/// It does NOT:
/// - Execute SPLIT.
/// - Execute MERGE.
/// - Execute COMPOSE.
/// - Modify Position identity.
/// - Modify Position runtime.
/// - Modify Position capabilities.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic value.
/// - Perform settlement.
/// - Create economic value.
/// - Destroy economic value.
///
/// Its responsibility is to ensure that a Composition:
///
///     READY
///       │
///       ▼
///   EXECUTING
///       │
///       ├──── COMPLETED
///       │
///       └──── FAILED
///
/// The actual economic execution is delegated to a later
/// Composition Runtime Executor layer.
contract CompositionExecutionManager {

    //////////////////////////////////////////////////////////////
    // RUNTIME COMPONENTS
    //////////////////////////////////////////////////////////////

    CompositionValidationManager public immutable
        validationManager;

    CompositionStateManager public immutable
        stateManager;

    CompositionOperationRegistry public immutable
        operationRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable executionAuthority;

    //////////////////////////////////////////////////////////////
    // EXECUTION TRACKING
    //////////////////////////////////////////////////////////////

    mapping(CompositionId => bool)
        private _executionStarted;

    mapping(CompositionId => bool)
        private _executionCompleted;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address validationManagerAddress,
        address stateManagerAddress,
        address operationRegistryAddress,
        address authority
    ) {
        if (
            validationManagerAddress ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            stateManagerAddress ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            operationRegistryAddress ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            authority ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        validationManager =
            CompositionValidationManager(
                validationManagerAddress
            );

        stateManager =
            CompositionStateManager(
                stateManagerAddress
            );

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        executionAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // START EXECUTION
    //////////////////////////////////////////////////////////////

    function beginExecution(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        if (
            _executionStarted[compositionId]
        ) {
            revert PositionAlreadyRegistered();
        }

        if (
            !_validateReadyComposition(
                compositionId
            )
        ) {
            revert UnsupportedOperation();
        }

        _executionStarted[compositionId] = true;

        stateManager.transition(
            compositionId,
            CompositionStates.EXECUTING
        );
    }

    //////////////////////////////////////////////////////////////
    // COMPLETE EXECUTION
    //////////////////////////////////////////////////////////////

    function completeExecution(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        if (
            !_executionStarted[compositionId]
        ) {
            revert PositionNotFound();
        }

        if (
            _executionCompleted[compositionId]
        ) {
            revert PositionAlreadyRegistered();
        }

        if (
            !stateManager.isState(
                compositionId,
                CompositionStates.EXECUTING
            )
        ) {
            revert InvalidStateTransition();
        }

        stateManager.transition(
            compositionId,
            CompositionStates.COMPLETED
        );

        _executionCompleted[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // FAIL EXECUTION
    //////////////////////////////////////////////////////////////

    function failExecution(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        if (
            !_executionStarted[compositionId]
        ) {
            revert PositionNotFound();
        }

        if (
            _executionCompleted[compositionId]
        ) {
            revert PositionAlreadyRegistered();
        }

        if (
            !stateManager.isState(
                compositionId,
                CompositionStates.EXECUTING
            )
        ) {
            revert InvalidStateTransition();
        }

        stateManager.transition(
            compositionId,
            CompositionStates.FAILED
        );

        _executionCompleted[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // EXECUTION STATUS
    //////////////////////////////////////////////////////////////

    function executionStarted(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool started
        )
    {
        return _executionStarted[
            compositionId
        ];
    }

    //////////////////////////////////////////////////////////////
    // COMPLETION STATUS
    //////////////////////////////////////////////////////////////

    function executionCompleted(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool completed
        )
    {
        return _executionCompleted[
            compositionId
        ];
    }

    //////////////////////////////////////////////////////////////
    // OPERATION
    //////////////////////////////////////////////////////////////

    function getExecutionOperation(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionOperationId operation
        )
    {
        _validateCompositionId(
            compositionId
        );

        if (
            !operationRegistry.exists(
                compositionId
            )
        ) {
            revert PositionNotFound();
        }

        return
            operationRegistry.getOperationType(
                compositionId
            );
    }

    //////////////////////////////////////////////////////////////
    // READY CHECK
    //////////////////////////////////////////////////////////////

    function isReadyForExecution(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool ready
        )
    {
        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            return false;
        }

        if (
            _executionStarted[
                compositionId
            ]
        ) {
            return false;
        }

        return
            validationManager
                .validateReadyForExecution(
                    compositionId
                );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL READY VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateReadyComposition(
        CompositionId compositionId
    )
        internal
        view
        returns (
            bool
        )
    {
        if (
            !validationManager
                .validateReadyForExecution(
                    compositionId
                )
        ) {
            return false;
        }

        CompositionOperationId operation =
            operationRegistry.getOperationType(
                compositionId
            );

        if (
            CompositionOperationId.unwrap(
                operation
            ) == bytes32(0)
        ) {
            return false;
        }

        if (
            !operationRegistry.isActive(
                compositionId
            )
        ) {
            return false;
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // COMPOSITION ID VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateCompositionId(
        CompositionId compositionId
    )
        internal
        pure
    {
        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            revert ZeroValue();
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
            msg.sender !=
            executionAuthority
        ) {
            revert Unauthorized();
        }
    }
}

