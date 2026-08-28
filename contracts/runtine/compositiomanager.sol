// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/Errors.sol";
import "../kernel/Types.sol";

import "./PositionCompositionManager.sol";
import "./CompositionRegistry.sol";
import "./CompositionOperationRegistry.sol";
import "./CompositionStateManager.sol";

/// @title PRC-369 Composition Manager
/// @author MINTer
/// @notice Coordinates the creation and validation of PRC-369 Compositions.
/// @dev
/// Runtime coordination layer between:
///
/// PositionCompositionManager
///      │
///      │ validates Position capabilities
///      ▼
/// CompositionRegistry
///      │
///      │ validates supported operation types
///      ▼
/// CompositionOperationRegistry
///      │
///      │ registers concrete Composition
///      ▼
/// CompositionStateManager
///      │
///      │ manages lifecycle
///      ▼
/// Composition Runtime
///
/// This contract does NOT:
/// - Modify Position identity.
/// - Modify Position Runtime.
/// - Modify Position capabilities.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Execute settlement.
/// - Create economic value.
/// - Destroy economic value.
/// - Execute SPLIT.
/// - Execute MERGE.
/// - Execute COMPOSE.
///
/// Economic execution belongs to later Runtime execution layers.
contract CompositionManager {

    //////////////////////////////////////////////////////////////
    // RUNTIME COMPONENTS
    //////////////////////////////////////////////////////////////

    /// @notice Position composition validation component.
    PositionCompositionManager public immutable positionCompositionManager;

    /// @notice Registry of supported Composition operation types.
    CompositionRegistry public immutable compositionRegistry;

    /// @notice Registry of concrete Composition operations.
    CompositionOperationRegistry public immutable operationRegistry;

    /// @notice Composition lifecycle state manager.
    CompositionStateManager public immutable stateManager;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to coordinate Compositions.
    address public immutable compositionAuthority;

    //////////////////////////////////////////////////////////////
    // COMPOSITION COUNTER
    //////////////////////////////////////////////////////////////

    /// @notice Internal sequence used to generate Composition identifiers.
    uint256 private _compositionNonce;

    //////////////////////////////////////////////////////////////
    // CREATED COMPOSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Tracks Compositions created through this Manager.
    mapping(CompositionId => bool) private _created;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition Manager.
    /// @param positionCompositionManagerAddress Position validation manager.
    /// @param compositionRegistryAddress Supported operation registry.
    /// @param operationRegistryAddress Concrete operation registry.
    /// @param stateManagerAddress Composition lifecycle manager.
    /// @param authority Composition Manager authority.
    constructor(
        address positionCompositionManagerAddress,
        address compositionRegistryAddress,
        address operationRegistryAddress,
        address stateManagerAddress,
        address authority
    ) {
        if (
            positionCompositionManagerAddress ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            compositionRegistryAddress ==
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
            stateManagerAddress ==
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

        positionCompositionManager =
            PositionCompositionManager(
                positionCompositionManagerAddress
            );

        compositionRegistry =
            CompositionRegistry(
                compositionRegistryAddress
            );

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        stateManager =
            CompositionStateManager(
                stateManagerAddress
            );

        compositionAuthority =
            authority;

        _compositionNonce = 0;
    }

    //////////////////////////////////////////////////////////////
    // CREATE COMPOSITION
    //////////////////////////////////////////////////////////////

    /// @notice Creates a new Composition for a supported operation.
    /// @param operation Composition operation type.
    /// @return compositionId Newly created Composition identifier.
    function createComposition(
        CompositionOperationId operation
    )
        external
        returns (
            CompositionId compositionId
        )
    {
        _authorize();

        _validateOperation(
            operation
        );

        compositionId =
            _generateCompositionId();

        operationRegistry.registerOperation(
            compositionId,
            operation
        );

        stateManager.initializeState(
            compositionId
        );

        _created[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // CREATE SPLIT
    //////////////////////////////////////////////////////////////

    /// @notice Creates a Composition for a Position SPLIT.
    /// @param positionId Position that will participate in SPLIT.
    /// @return compositionId Newly created Composition.
    function createSplit(
        PositionId positionId
    )
        external
        returns (
            CompositionId compositionId
        )
    {
        _authorize();

        if (
            !positionCompositionManager.supportsSplit(
                positionId
            )
        ) {
            revert UnsupportedOperation();
        }

        compositionId =
            _generateCompositionId();

        operationRegistry.registerOperation(
            compositionId,
            CompositionOperations.SPLIT
        );

        stateManager.initializeState(
            compositionId
        );

        _created[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // CREATE MERGE
    //////////////////////////////////////////////////////////////

    /// @notice Creates a Composition for a Position MERGE.
    /// @param positionId Position that will participate in MERGE.
    /// @return compositionId Newly created Composition.
    function createMerge(
        PositionId positionId
    )
        external
        returns (
            CompositionId compositionId
        )
    {
        _authorize();

        if (
            !positionCompositionManager.supportsMerge(
                positionId
            )
        ) {
            revert UnsupportedOperation();
        }

        compositionId =
            _generateCompositionId();

        operationRegistry.registerOperation(
            compositionId,
            CompositionOperations.MERGE
        );

        stateManager.initializeState(
            compositionId
        );

        _created[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // CREATE COMPOSE
    //////////////////////////////////////////////////////////////

    /// @notice Creates a Composition for a Position COMPOSE.
    /// @param positionId Position that will participate in COMPOSE.
    /// @return compositionId Newly created Composition.
    function createCompose(
        PositionId positionId
    )
        external
        returns (
            CompositionId compositionId
        )
    {
        _authorize();

        if (
            !positionCompositionManager.supportsComposition(
                positionId
            )
        ) {
            revert UnsupportedOperation();
        }

        compositionId =
            _generateCompositionId();

        operationRegistry.registerOperation(
            compositionId,
            CompositionOperations.COMPOSE
        );

        stateManager.initializeState(
            compositionId
        );

        _created[compositionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Validates a Position against a Composition operation.
    /// @param positionId Position identifier.
    /// @param operation Composition operation type.
    /// @return valid True when supported.
    function validatePosition(
        PositionId positionId,
        CompositionOperationId operation
    )
        external
        view
        returns (
            bool valid
        )
    {
        if (
            !_createdPositionExists(
                positionId
            )
        ) {
            revert PositionNotFound();
        }

        if (
            CompositionOperationId.unwrap(
                operation
            ) == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (
            !positionCompositionManager.supportsOperation(
                positionId,
                operation
            )
        ) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSITION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition is fully registered.
    /// @param compositionId Composition identifier.
    /// @return valid True when valid.
    function validateComposition(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool valid
        )
    {
        return _validateCompositionInternal(
            compositionId
        );
    }

    //////////////////////////////////////////////////////////////
    // GET COMPOSITION OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Returns the operation type assigned to a Composition.
    /// @param compositionId Composition identifier.
    /// @return operation Composition operation type.
    function getCompositionOperation(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionOperationId operation
        )
    {
        if (
            !_validateCompositionInternal(
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
    // GET COMPOSITION STATE
    //////////////////////////////////////////////////////////////

    /// @notice Returns the lifecycle state of a Composition.
    /// @param compositionId Composition identifier.
    /// @return state Current Composition state.
    function getCompositionState(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionStateId state
        )
    {
        if (
            !_validateCompositionInternal(
                compositionId
            )
        ) {
            revert PositionNotFound();
        }

        return
            stateManager.getState(
                compositionId
            );
    }

    //////////////////////////////////////////////////////////////
    // CHECK CREATED
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition was created by this Manager.
    /// @param compositionId Composition identifier.
    /// @return created True when created.
    function isCreated(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool created
        )
    {
        return _created[compositionId];
    }

    //////////////////////////////////////////////////////////////
    // CHECK OPERATION SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an operation type is currently supported.
    /// @param operation Composition operation type.
    /// @return supported True when active.
    function isOperationSupported(
        CompositionOperationId operation
    )
        external
        view
        returns (
            bool supported
        )
    {
        if (
            CompositionOperationId.unwrap(
                operation
            ) == bytes32(0)
        ) {
            return false;
        }

        return
            compositionRegistry.isActive(
                operation
            );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL OPERATION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @dev Validates that a Composition operation is supported.
    function _validateOperation(
        CompositionOperationId operation
    )
        internal
        view
    {
        if (
            CompositionOperationId.unwrap(
                operation
            ) == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (
            !compositionRegistry.isActive(
                operation
            )
        ) {
            revert UnsupportedOperation();
        }
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL COMPOSITION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @dev Internal validation used by multiple Runtime functions.
    ///
    /// A Composition is valid only when:
    /// 1. It was created by this Manager.
    /// 2. It exists in CompositionOperationRegistry.
    /// 3. Its lifecycle was initialized.
    function _validateCompositionInternal(
        CompositionId compositionId
    )
        internal
        view
        returns (
            bool
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
            !_created[compositionId]
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
            !stateManager.isInitialized(
                compositionId
            )
        ) {
            return false;
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL POSITION CHECK
    //////////////////////////////////////////////////////////////

    /// @dev Checks whether the Position exists through the
    /// authoritative Position Registry exposed by
    /// PositionCompositionManager.
    function _createdPositionExists(
        PositionId positionId
    )
        internal
        view
        returns (
            bool
        )
    {
        if (
            PositionId.unwrap(
                positionId
            ) == 0
        ) {
            return false;
        }

        return
            positionCompositionManager
                .positionRegistry()
                .positionExists(
                    positionId
                );
    }

    //////////////////////////////////////////////////////////////
    // GENERATE COMPOSITION ID
    //////////////////////////////////////////////////////////////

    /// @dev Generates a unique CompositionId.
    function _generateCompositionId()
        internal
        returns (
            CompositionId compositionId
        )
    {
        _compositionNonce++;

        compositionId =
            CompositionId.wrap(
                keccak256(
                    abi.encode(
                        address(this),
                        block.chainid,
                        _compositionNonce
                    )
                )
            );
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @dev Validates Composition Manager authority.
    function _authorize()
        internal
        view
    {
        if (
            msg.sender !=
            compositionAuthority
        ) {
            revert Unauthorized();
        }
    }
}
