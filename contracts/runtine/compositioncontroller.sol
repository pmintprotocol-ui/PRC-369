// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "./CompositionRegistry.sol";
import "./CompositionOperationRegistry.sol";
import "./CompositionParticipants.sol";
import "./PositionCompositionManager.sol";

/// @title PRC-369 Composition Controller
/// @author MINTer
/// @notice Coordinates the lifecycle of PRC-369 composition operations.
/// @dev
/// This controller orchestrates composition registration, participant
/// registration and structural validation.
///
/// It does NOT:
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic values.
/// - Execute settlement.
/// - Create or destroy Positions.
/// - Perform the economic effects of SPLIT, MERGE or COMPOSE.
///
/// It only coordinates the structural composition workflow.

contract CompositionController {

    //////////////////////////////////////////////////////////////
    // COMPONENTS
    //////////////////////////////////////////////////////////////

    /// @notice Composition Registry.
    CompositionRegistry public immutable compositionRegistry;

    /// @notice Concrete Composition Operation Registry.
    CompositionOperationRegistry public immutable operationRegistry;

    /// @notice Composition participant registry.
    CompositionParticipants public immutable participants;

    /// @notice Position composition manager.
    PositionCompositionManager public immutable compositionManager;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to coordinate compositions.
    address public immutable controllerAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address compositionRegistryAddress,
        address operationRegistryAddress,
        address participantsAddress,
        address compositionManagerAddress,
        address authority
    ) {
        if (
            compositionRegistryAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            operationRegistryAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            participantsAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            compositionManagerAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            authority == address(0)
        ) {
            revert ZeroAddress();
        }

        compositionRegistry =
            CompositionRegistry(
                compositionRegistryAddress
            );

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        participants =
            CompositionParticipants(
                participantsAddress
            );

        compositionManager =
            PositionCompositionManager(
                compositionManagerAddress
            );

        controllerAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // CREATE COMPOSITION
    //////////////////////////////////////////////////////////////

    /// @notice Creates a new structural composition operation.
    /// @param compositionId Unique composition identifier.
    /// @param operation Composition operation type.
    function createComposition(
        CompositionId compositionId,
        CompositionOperationId operation
    )
        external
    {
        _authorize();

        operationRegistry.registerOperation(
            compositionId,
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // ADD SOURCE
    //////////////////////////////////////////////////////////////

    /// @notice Adds a source Position to a composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Source Position identifier.
    function addSource(
        CompositionId compositionId,
        PositionId positionId
    )
        external
    {
        _authorize();

        if (
            !operationRegistry.isActive(
                compositionId
            )
        ) {
            revert UnsupportedOperation();
        }

        participants.addSource(
            compositionId,
            positionId
        );
    }

    //////////////////////////////////////////////////////////////
    // ADD TARGET
    //////////////////////////////////////////////////////////////

    /// @notice Adds a target Position to a composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Target Position identifier.
    function addTarget(
        CompositionId compositionId,
        PositionId positionId
    )
        external
    {
        _authorize();

        if (
            !operationRegistry.isActive(
                compositionId
            )
        ) {
            revert UnsupportedOperation();
        }

        participants.addTarget(
            compositionId,
            positionId
        );
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSITION
    //////////////////////////////////////////////////////////////

    /// @notice Validates the structural requirements of a composition.
    /// @param compositionId Composition identifier.
    /// @return valid True when the composition is structurally valid.
    function validateComposition(
        CompositionId compositionId
    )
        public
        view
        returns (bool valid)
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
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

        CompositionOperationId operation =
            operationRegistry.getOperationType(
                compositionId
            );

        uint256 sourceCount =
            participants.sourceCount(
                compositionId
            );

        uint256 targetCount =
            participants.targetCount(
                compositionId
            );

        //////////////////////////////////////////////////////////
        // SPLIT
        //////////////////////////////////////////////////////////

        if (
            CompositionOperationId.unwrap(operation)
            == CompositionOperationId.unwrap(
                CompositionOperations.SPLIT
            )
        ) {
            return _validateSplit(
                compositionId,
                sourceCount,
                targetCount
            );
        }

        //////////////////////////////////////////////////////////
        // MERGE
        //////////////////////////////////////////////////////////

        if (
            CompositionOperationId.unwrap(operation)
            == CompositionOperationId.unwrap(
                CompositionOperations.MERGE
            )
        ) {
            return _validateMerge(
                compositionId,
                sourceCount,
                targetCount
            );
        }

        //////////////////////////////////////////////////////////
        // COMPOSE
        //////////////////////////////////////////////////////////

        if (
            CompositionOperationId.unwrap(operation)
            == CompositionOperationId.unwrap(
                CompositionOperations.COMPOSE
            )
        ) {
            return _validateCompose(
                compositionId,
                sourceCount,
                targetCount
            );
        }

        return false;
    }

    //////////////////////////////////////////////////////////////
    // READY CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Determines whether a composition is ready for execution.
    /// @param compositionId Composition identifier.
    /// @return ready True when the composition is structurally ready.
    function isReady(
        CompositionId compositionId
    )
        external
        view
        returns (bool ready)
    {
        return validateComposition(
            compositionId
        );
    }

    //////////////////////////////////////////////////////////////
    // OPERATION TYPE
    //////////////////////////////////////////////////////////////

    /// @notice Returns the operation type of a composition.
    /// @param compositionId Composition identifier.
    /// @return operation Composition operation type.
    function getOperationType(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionOperationId operation
        )
    {
        return operationRegistry.getOperationType(
            compositionId
        );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL SPLIT VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateSplit(
        CompositionId compositionId,
        uint256 sourceCount,
        uint256 targetCount
    )
        internal
        view
        returns (bool)
    {
        if (sourceCount != 1) {
            return false;
        }

        if (targetCount < 2) {
            return false;
        }

        PositionId source =
            participants.getSource(
                compositionId,
                0
            );

        return compositionManager.supportsSplit(
            source
        );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL MERGE VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateMerge(
        CompositionId compositionId,
        uint256 sourceCount,
        uint256 targetCount
    )
        internal
        view
        returns (bool)
    {
        if (sourceCount < 2) {
            return false;
        }

        if (targetCount != 1) {
            return false;
        }

        for (
            uint256 i = 0;
            i < sourceCount;
            i++
        ) {
            PositionId source =
                participants.getSource(
                    compositionId,
                    i
                );

            if (
                !compositionManager.supportsMerge(
                    source
                )
            ) {
                return false;
            }
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL COMPOSE VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateCompose(
        CompositionId compositionId,
        uint256 sourceCount,
        uint256 targetCount
    )
        internal
        view
        returns (bool)
    {
        if (sourceCount < 2) {
            return false;
        }

        if (targetCount != 1) {
            return false;
        }

        for (
            uint256 i = 0;
            i < sourceCount;
            i++
        ) {
            PositionId source =
                participants.getSource(
                    compositionId,
                    i
                );

            if (
                !compositionManager.supportsComposition(
                    source
                )
            ) {
                return false;
            }
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (
            msg.sender != controllerAuthority
        ) {
            revert Unauthorized();
        }
    }
}
