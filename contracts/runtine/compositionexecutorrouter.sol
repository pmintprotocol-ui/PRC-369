// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/CompositionStates.sol";
import "../kernel/Errors.sol";

import "./CompositionOperationRegistry.sol";
import "./CompositionStateManager.sol";
import "./CompositionExecutionManager.sol";

/// @title PRC-369 Composition Executor Router
/// @author MINTer
/// @notice Resolves which execution path corresponds to a
///         PRC-369 Composition.
/// @dev
/// This contract is a routing layer only.
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
/// Its responsibility is ONLY to determine the execution
/// path associated with the Composition operation.
///
/// Execution remains the responsibility of dedicated
/// operation executors.

contract CompositionExecutorRouter {

    //////////////////////////////////////////////////////////////
    // RUNTIME COMPONENTS
    //////////////////////////////////////////////////////////////

    /// @notice Registry containing the operation assigned to
    ///         each Composition.
    CompositionOperationRegistry public immutable
        operationRegistry;

    /// @notice Manager responsible for Composition lifecycle.
    CompositionStateManager public immutable
        stateManager;

    /// @notice Manager responsible for beginning execution.
    CompositionExecutionManager public immutable
        executionManager;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to resolve execution paths.
    address public immutable routerAuthority;

    //////////////////////////////////////////////////////////////
    // EXECUTION PATH IDENTIFIERS
    //////////////////////////////////////////////////////////////

    /// @notice Execution path identifiers.
    ///
    /// NONE
    /// SPLIT
    /// MERGE
    /// COMPOSE
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

    /// @notice Initializes the Executor Router.
    /// @param operationRegistryAddress Composition operation registry.
    /// @param stateManagerAddress Composition state manager.
    /// @param executionManagerAddress Composition execution manager.
    /// @param authority Router authority.
    constructor(
        address operationRegistryAddress,
        address stateManagerAddress,
        address executionManagerAddress,
        address authority
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

        if (
            executionManagerAddress ==
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

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        stateManager =
            CompositionStateManager(
                stateManagerAddress
            );

        executionManager =
            CompositionExecutionManager(
                executionManagerAddress
            );

        routerAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE EXECUTION PATH
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the execution path of a Composition.
    /// @dev
    /// The Composition must:
    /// 1. Exist in the operation registry.
    /// 2. Have an active operation.
    /// 3. Be initialized.
    /// 4. Be in EXECUTING state.
    ///
    /// No state is modified.
    ///
    /// @param compositionId Composition identifier.
    /// @return path Execution path identifier.
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

        CompositionOperationId operation =
            operationRegistry.getOperationType(
                compositionId
            );

        return _resolveOperationPath(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // CHECK PATH
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition resolves to a
    ///         specific execution path.
    /// @param compositionId Composition identifier.
    /// @param expectedPath Expected execution path.
    /// @return matches True when the path matches.
    function isPath(
        CompositionId compositionId,
        bytes32 expectedPath
    )
        external
        view
        returns (
            bool matches
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

        CompositionOperationId operation =
            operationRegistry.getOperationType(
                compositionId
            );

        return
            _resolveOperationPath(
                operation
            ) == expectedPath;
    }

    //////////////////////////////////////////////////////////////
    // OPERATION PATH
    //////////////////////////////////////////////////////////////

    /// @notice Resolves an operation type without requiring
    ///         a Composition.
    /// @param operation Composition operation type.
    /// @return path Corresponding execution path.
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
    // SPLIT CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether the Composition is routed to SPLIT.
    /// @param compositionId Composition identifier.
    /// @return split True when routed to SPLIT.
    function isSplit(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool split
        )
    {
        return
            this.isPath(
                compositionId,
                PATH_SPLIT
            );
    }

    //////////////////////////////////////////////////////////////
    // MERGE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether the Composition is routed to MERGE.
    /// @param compositionId Composition identifier.
    /// @return merge True when routed to MERGE.
    function isMerge(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool merge
        )
    {
        return
            this.isPath(
                compositionId,
                PATH_MERGE
            );
    }

    //////////////////////////////////////////////////////////////
    // COMPOSE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether the Composition is routed to COMPOSE.
    /// @param compositionId Composition identifier.
    /// @return compose True when routed to COMPOSE.
    function isCompose(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool compose
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

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (
            msg.sender !=
            routerAuthority
        ) {
            revert Unauthorized();
        }
    }
}
