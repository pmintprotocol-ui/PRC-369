// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionStates.sol";

import "./CompositionOperationRegistry.sol";
import "./CompositionPositionRegistry.sol";
import "./CompositionStateManager.sol";
import "./PositionCompositionManager.sol";

/// @title PRC-369 Composition Validation Manager
/// @author MINTer
/// @notice Validates whether a Composition is structurally ready
///         for the execution Runtime.
///
/// @dev
/// This contract is a validation layer only.
///
/// It does NOT:
/// - Create Compositions.
/// - Register operation types.
/// - Register Positions.
/// - Modify Position capabilities.
/// - Modify Position state.
/// - Modify Composition state.
/// - Execute SPLIT.
/// - Execute MERGE.
/// - Execute COMPOSE.
/// - Transfer assets.
/// - Modify EconomicState.
/// - Calculate economic value.
/// - Perform settlement.
/// - Create or destroy Positions.
///
/// Its only responsibility is to verify that the required
/// Composition components are correctly configured before
/// execution is delegated to a later Runtime layer.

contract CompositionValidationManager {

    //////////////////////////////////////////////////////////////
    // RUNTIME COMPONENTS
    //////////////////////////////////////////////////////////////

    /// @notice Registry containing the concrete operation
    ///         assigned to each Composition.
    CompositionOperationRegistry public immutable operationRegistry;

    /// @notice Registry containing the Positions participating
    ///         in each Composition.
    CompositionPositionRegistry public immutable positionRegistry;

    /// @notice Manager responsible for Position composition
    ///         capability validation.
    PositionCompositionManager public immutable
        positionCompositionManager;

    /// @notice Manager responsible for Composition lifecycle state.
    CompositionStateManager public immutable stateManager;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority reserved for controlled Runtime integration.
    address public immutable validationAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition Validation Manager.
    /// @param operationRegistryAddress Concrete Composition operation
    ///        registry.
    /// @param positionRegistryAddress Composition Position registry.
    /// @param positionCompositionManagerAddress Position composition
    ///        capability manager.
    /// @param stateManagerAddress Composition lifecycle state manager.
    /// @param authority Validation authority.
    constructor(
        address operationRegistryAddress,
        address positionRegistryAddress,
        address positionCompositionManagerAddress,
        address stateManagerAddress,
        address authority
    ) {
        if (operationRegistryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (positionRegistryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (positionCompositionManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (stateManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        positionRegistry =
            CompositionPositionRegistry(
                positionRegistryAddress
            );

        positionCompositionManager =
            PositionCompositionManager(
                positionCompositionManagerAddress
            );

        stateManager =
            CompositionStateManager(
                stateManagerAddress
            );

        validationAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // BASIC COMPOSITION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition exists and has
    ///         a valid operation and initialized lifecycle.
    function validateComposition(
        CompositionId compositionId
    )
        external
        view
        returns (bool valid)
    {
        return _validateCompositionView(
            compositionId
        );
    }

    //////////////////////////////////////////////////////////////
    // PARTICIPANT VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether all registered Positions support
    ///         the operation assigned to the Composition.
    function validateParticipants(
        CompositionId compositionId
    )
        external
        view
        returns (bool valid)
    {
        if (
            !_validateCompositionView(
                compositionId
            )
        ) {
            return false;
        }

        CompositionOperationId operation =
            operationRegistry.getOperationType(
                compositionId
            );

        PositionId[] memory positions =
            positionRegistry.getPositions(
                compositionId
            );

        if (positions.length == 0) {
            return false;
        }

        uint256 length = positions.length;

        for (
            uint256 i = 0;
            i < length;
            i++
        ) {
            if (
                !positionCompositionManager
                    .supportsOperation(
                        positions[i],
                        operation
                    )
            ) {
                return false;
            }
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // FULL EXECUTION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Performs complete structural validation of a
    ///         Composition before execution.
    ///
    /// @dev
    /// A Composition is structurally valid when:
    ///
    /// 1. The Composition has a valid identifier.
    /// 2. Its operation is registered.
    /// 3. Its operation is active.
    /// 4. Its lifecycle is initialized.
    /// 5. At least one Position participates.
    /// 6. Every participating Position supports the operation.
    ///
    /// This function does not modify state.
    function validateForExecution(
        CompositionId compositionId
    )
        external
        view
        returns (bool valid)
    {
        return _validateForExecutionView(
            compositionId
        );
    }

    //////////////////////////////////////////////////////////////
    // REQUIRE VALID COMPOSITION
    //////////////////////////////////////////////////////////////

    /// @notice Reverts unless the Composition is structurally
    ///         valid for execution.
    function requireValidForExecution(
        CompositionId compositionId
    )
        external
        view
    {
        if (
            !_validateForExecutionView(
                compositionId
            )
        ) {
            revert UnsupportedOperation();
        }
    }

    //////////////////////////////////////////////////////////////
    // OPERATION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether the operation assigned to a
    ///         Composition is currently active.
    function isOperationActive(
        CompositionId compositionId
    )
        external
        view
        returns (bool active)
    {
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

        return
            operationRegistry.isActive(
                compositionId
            );
    }

    //////////////////////////////////////////////////////////////
    // PARTICIPANT COUNT
    //////////////////////////////////////////////////////////////

    /// @notice Returns the number of Positions participating
    ///         in a Composition.
    function participantCount(
        CompositionId compositionId
    )
        external
        view
        returns (uint256 count)
    {
        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            return 0;
        }

        return
            positionRegistry.positionCount(
                compositionId
            );
    }

    //////////////////////////////////////////////////////////////
    // READY STATE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition has reached READY.
    ///
    /// @dev
    /// This function only reads lifecycle state.
    /// It does not transition the Composition.
    function isReady(
        CompositionId compositionId
    )
        external
        view
        returns (bool ready)
    {
        if (
            !stateManager.isInitialized(
                compositionId
            )
        ) {
            return false;
        }

        return
            stateManager.isState(
                compositionId,
                CompositionStates.READY
            );
    }

    //////////////////////////////////////////////////////////////
    // FULL READY VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition is structurally valid
    ///         and currently in READY state.
    function validateReadyForExecution(
        CompositionId compositionId
    )
        external
        view
        returns (bool valid)
    {
        if (
            !_validateForExecutionView(
                compositionId
            )
        ) {
            return false;
        }

        return
            stateManager.isState(
                compositionId,
                CompositionStates.READY
            );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL COMPOSITION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @dev Validates the basic Composition structure.
    ///
    /// Requirements:
    /// - Non-zero CompositionId.
    /// - Operation exists.
    /// - Operation is active.
    /// - Composition lifecycle is initialized.
    function _validateCompositionView(
        CompositionId compositionId
    )
        internal
        view
        returns (bool)
    {
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

        return true;
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL EXECUTION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @dev Performs complete structural validation.
    function _validateForExecutionView(
        CompositionId compositionId
    )
        internal
        view
        returns (bool)
    {
        if (
            !_validateCompositionView(
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

        PositionId[] memory positions =
            positionRegistry.getPositions(
                compositionId
            );

        if (positions.length == 0) {
            return false;
        }

        uint256 length = positions.length;

        for (
            uint256 i = 0;
            i < length;
            i++
        ) {
            if (
                !positionCompositionManager
                    .supportsOperation(
                        positions[i],
                        operation
                    )
            ) {
                return false;
            }
        }

        return true;
    }
}

