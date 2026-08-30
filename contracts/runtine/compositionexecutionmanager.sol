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

    /// @notice Validates whether a Composition is structurally
    ///         ready for execution.
    CompositionValidationManager public immutable
        validationManager;

    /// @notice Manages the lifecycle state of Compositions.
    CompositionStateManager public immutable
        stateManager;

    /// @notice Resolves the operation assigned to a Composition.
    CompositionOperationRegistry public immutable
        operationRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to coordinate execution lifecycle.
    address public immutable executionAuthority;

    //////////////////////////////////////////////////////////////
    // EXECUTION TRACKING
    //////////////////////////////////////////////////////////////

    /// @notice Tracks whether execution has been started.
    mapping(CompositionId => bool)
        private _executionStarted;

    /// @notice Tracks whether execution has completed.
    mapping(CompositionId => bool)
        private _executionCompleted;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition Execution Manager.
    /// @param validationManagerAddress Composition validation manager.
    /// @param stateManagerAddress Composition state manager.
    /// @param operationRegistryAddress Composition operation registry.
    /// @param authority Execution authority.
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

    /// @notice Moves a valid Composition from READY to EXECUTING.
    /// @dev
    /// This function does not perform the economic operation.
    ///
    /// Required conditions:
    /// 1. Composition is structurally valid.
    /// 2. All participants support the operation.
    /// 3. Operation is active.
    /// 4. Composition is in READY state.
    /// 5. Execution has not already started.
    ///
    /// @param compositionId Composition identifier.
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

    /// @notice Marks an executing Composition as COMPLETED.
    /// @dev
    /// This function only coordinates lifecycle state.
    /// It does not perform the economic execution itself.
    ///
    /// @param compositionId Composition identifier.
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

    /// @notice Marks an executing Composition as FAILED.
    /// @dev
    /// This function only coordinates lifecycle state.
    /// It does not perform rollback or settlement.
    ///
    /// @param compositionId Composition identifier.
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

    /// @notice Checks whether execution has started.
    /// @param compositionId Composition identifier.
    /// @return started True when execution has started.
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

    /// @notice Checks whether execution has completed.
    /// @param compositionId Composition identifier.
    /// @return completed True when execution reached a terminal state.
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

    /// @notice Returns the operation assigned to the Composition.
    /// @param compositionId Composition identifier.
    /// @return operation Composition operation type.
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

    /// @notice Checks whether a Composition can begin execution.
    /// @param compositionId Composition identifier.
    /// @return ready True when ready.
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

    /// @dev Performs the complete pre-execution validation.
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

