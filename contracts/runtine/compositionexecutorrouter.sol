// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/CompositionStates.sol";
import "../kernel/Errors.sol";

import "./CompositionOperationRegistry.sol";
import "./CompositionStateManager.sol";

/// @title PRC-369 Composition Executor Router
/// @author MINTer
/// @notice Resolves the execution path associated with a Composition.
/// @dev
/// This contract is a pure routing and validation layer.
///
/// It does NOT:
/// - Execute SPLIT.
/// - Execute MERGE.
/// - Execute COMPOSE.
/// - Modify Positions.
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
/// Its sole responsibility is to resolve the operation type of a
/// Composition into its corresponding execution path.
///
/// Dedicated execution contracts remain responsible for execution.

contract CompositionExecutorRouter {

    //////////////////////////////////////////////////////////////
    // RUNTIME COMPONENTS
    //////////////////////////////////////////////////////////////

    /// @notice Registry containing the operation assigned to
    ///         each Composition.
    CompositionOperationRegistry public immutable
        operationRegistry;

    /// @notice Manager responsible for Composition lifecycle state.
    CompositionStateManager public immutable
        stateManager;

    //////////////////////////////////////////////////////////////
    // EXECUTION PATH IDENTIFIERS
    //////////////////////////////////////////////////////////////

    bytes32 public constant PATH_NONE =
        bytes32(0);

    bytes32 public constant PATH_SPLIT =
        keccak256("PRC369_EXECUTOR_SPLIT");

    bytes32 public constant PATH_MERGE =
        keccak256("PRC369_EXECUTOR_MERGE");

    bytes32 public constant PATH_COMPOSE =
        keccak256("PRC369_EXECUTOR_COMPOSE");

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address operationRegistryAddress,
        address stateManagerAddress
    ) {
        if (
            operationRegistryAddress ==
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

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        stateManager =
            CompositionStateManager(
                stateManagerAddress
            );
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE EXECUTION PATH
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the execution path of a Composition.
    /// @dev
    /// The Composition must:
    /// - exist;
    /// - have an active operation;
    /// - have initialized lifecycle state;
    /// - be in EXECUTING state.
    function resolvePath(
        CompositionId compositionId
    )
        external
        view
        returns (
            bytes32 path
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

        if (
            !operationRegistry.isActive(
                compositionId
            )
        ) {
            revert UnsupportedOperation();
        }

        if (
            !stateManager.isInitialized(
                compositionId
            )
        ) {
            revert PositionNotFound();
        }

        if (
            !stateManager.isState(
                compositionId,
                CompositionStates.EXECUTING
            )
        ) {
            revert InvalidStateTransition();
        }

        return _resolveOperationPath(
            operationRegistry.getOperationType(
                compositionId
            )
        );
    }

    //////////////////////////////////////////////////////////////
    // CHECK PATH
    //////////////////////////////////////////////////////////////

    function isPath(
        CompositionId compositionId,
        bytes32 expectedPath
    )
        external
        view
        returns (
            bool
        )
    {
        if (
            expectedPath == PATH_NONE
        ) {
            return false;
        }

        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            return false;
        }

        if (
            !operationRegistry.exists(
                compositionId
            )
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

        if (
            !stateManager.isInitialized(
                compositionId
            )
        ) {
            return false;
        }

        if (
            !stateManager.isState(
                compositionId,
                CompositionStates.EXECUTING
            )
        ) {
            return false;
        }

        return
            _resolveOperationPath(
                operationRegistry.getOperationType(
                    compositionId
                )
            )
            ==
            expectedPath;
    }

    //////////////////////////////////////////////////////////////
    // OPERATION PATH
    //////////////////////////////////////////////////////////////

    function resolveOperationPath(
        CompositionOperationId operation
    )
        external
        pure
        returns (
            bytes32 path
        )
    {
        if (
            CompositionOperationId.unwrap(
                operation
            ) == bytes32(0)
        ) {
            revert ZeroValue();
        }

        return _resolveOperationPath(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // SPLIT
    //////////////////////////////////////////////////////////////

    function isSplit(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool
        )
    {
        return
            this.isPath(
                compositionId,
                PATH_SPLIT
            );
    }

    //////////////////////////////////////////////////////////////
    // MERGE
    //////////////////////////////////////////////////////////////

    function isMerge(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool
        )
    {
        return
            this.isPath(
                compositionId,
                PATH_MERGE
            );
    }

    //////////////////////////////////////////////////////////////
    // COMPOSE
    //////////////////////////////////////////////////////////////

    function isCompose(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool
        )
    {
        return
            this.isPath(
                compositionId,
                PATH_COMPOSE
            );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL ROUTING
    //////////////////////////////////////////////////////////////

    function _resolveOperationPath(
        CompositionOperationId operation
    )
        internal
        pure
        returns (
            bytes32 path
        )
    {
        if (
            CompositionOperationId.unwrap(
                operation
            )
            ==
            CompositionOperationId.unwrap(
                CompositionOperations.SPLIT
            )
        ) {
            return PATH_SPLIT;
        }

        if (
            CompositionOperationId.unwrap(
                operation
            )
            ==
            CompositionOperationId.unwrap(
                CompositionOperations.MERGE
            )
        ) {
            return PATH_MERGE;
        }

        if (
            CompositionOperationId.unwrap(
                operation
            )
            ==
            CompositionOperationId.unwrap(
                CompositionOperations.COMPOSE
            )
        ) {
            return PATH_COMPOSE;
        }

        revert UnsupportedOperation();
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
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            revert ZeroValue();
        }
    }
}
