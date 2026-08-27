// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CapabilityFlags.sol";
import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";

import "./PositionRegistry.sol";
import "./CapabilityManager.sol";
import "./CompositionRegistry.sol";

/// @title PRC-369 Position Composition Manager
/// @author MINTer
/// @notice Validates whether Positions support PRC-369 Composition operations.
/// @dev
/// Runtime component responsible for validating the participation of
/// Positions in Composition operations.
///
/// This contract does NOT:
/// - Define Position identity.
/// - Define Composition identity.
/// - Store Position runtime.
/// - Store Composition state.
/// - Execute economic settlement.
/// - Transfer assets.
/// - Create or destroy economic value.
/// - Modify Position capabilities.
/// - Modify Position lifecycle state.
///
/// Composition semantics are defined by the Kernel.
/// Runtime components enforce those semantics.
contract PositionCompositionManager {

    //////////////////////////////////////////////////////////////
    // REGISTRIES
    //////////////////////////////////////////////////////////////

    PositionRegistry public immutable positionRegistry;

    CapabilityManager public immutable capabilityManager;

    CompositionRegistry public immutable compositionRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable compositionAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address registryAddress,
        address capabilityManagerAddress,
        address compositionRegistryAddress,
        address authority
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (capabilityManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (compositionRegistryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        positionRegistry =
            PositionRegistry(registryAddress);

        capabilityManager =
            CapabilityManager(
                capabilityManagerAddress
            );

        compositionRegistry =
            CompositionRegistry(
                compositionRegistryAddress
            );

        compositionAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // SPLIT SUPPORT
    //////////////////////////////////////////////////////////////

    function supportsSplit(
        PositionId positionId
    )
        external
        view
        returns (bool supported)
    {
        return _supportsSplit(positionId);
    }

    //////////////////////////////////////////////////////////////
    // MERGE SUPPORT
    //////////////////////////////////////////////////////////////

    function supportsMerge(
        PositionId positionId
    )
        external
        view
        returns (bool supported)
    {
        return _supportsMerge(positionId);
    }

    //////////////////////////////////////////////////////////////
    // COMPOSE SUPPORT
    //////////////////////////////////////////////////////////////

    function supportsComposition(
        PositionId positionId
    )
        external
        view
        returns (bool supported)
    {
        return _supportsComposition(positionId);
    }

    //////////////////////////////////////////////////////////////
    // GENERAL OPERATION SUPPORT
    //////////////////////////////////////////////////////////////

    function supportsOperation(
        PositionId positionId,
        CompositionOperationId operation
    )
        external
        view
        returns (bool supported)
    {
        return _supportsOperation(
            positionId,
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE SPLIT
    //////////////////////////////////////////////////////////////

    function validateSplit(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (!_supportsSplit(positionId)) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE MERGE
    //////////////////////////////////////////////////////////////

    function validateMerge(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (!_supportsMerge(positionId)) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSE
    //////////////////////////////////////////////////////////////

    function validateComposition(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (!_supportsComposition(positionId)) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE GENERAL OPERATION
    //////////////////////////////////////////////////////////////

    function validateOperation(
        PositionId positionId,
        CompositionOperationId operation
    )
        external
        view
        returns (bool valid)
    {
        if (
            !_supportsOperation(
                positionId,
                operation
            )
        ) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL GENERAL OPERATION CHECK
    //////////////////////////////////////////////////////////////

    function _supportsOperation(
        PositionId positionId,
        CompositionOperationId operation
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId) == 0
        ) {
            return false;
        }

        if (
            !positionRegistry.positionExists(
                positionId
            )
        ) {
            return false;
        }

        if (
            CompositionOperationId.unwrap(operation)
            == bytes32(0)
        ) {
            return false;
        }

        if (
            !compositionRegistry.isActive(
                operation
            )
        ) {
            return false;
        }

        //////////////////////////////////////////////////////////
        // SPLIT
        //////////////////////////////////////////////////////////

        if (
            CompositionOperationId.unwrap(operation)
            ==
            CompositionOperationId.unwrap(
                CompositionOperations.SPLIT
            )
        ) {
            return capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.SPLITTABLE
            );
        }

        //////////////////////////////////////////////////////////
        // MERGE
        //////////////////////////////////////////////////////////

        if (
            CompositionOperationId.unwrap(operation)
            ==
            CompositionOperationId.unwrap(
                CompositionOperations.MERGE
            )
        ) {
            return capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.MERGEABLE
            );
        }

        //////////////////////////////////////////////////////////
        // COMPOSE
        //////////////////////////////////////////////////////////

        if (
            CompositionOperationId.unwrap(operation)
            ==
            CompositionOperationId.unwrap(
                CompositionOperations.COMPOSE
            )
        ) {
            return capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.COMPOSABLE
            );
        }

        return false;
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL SPLIT CHECK
    //////////////////////////////////////////////////////////////

    function _supportsSplit(
        PositionId positionId
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId) == 0
        ) {
            return false;
        }

        if (
            !positionRegistry.positionExists(
                positionId
            )
        ) {
            return false;
        }

        if (
            !compositionRegistry.isActive(
                CompositionOperations.SPLIT
            )
        ) {
            return false;
        }

        return capabilityManager.hasCapability(
            positionId,
            CapabilityFlags.SPLITTABLE
        );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL MERGE CHECK
    //////////////////////////////////////////////////////////////

    function _supportsMerge(
        PositionId positionId
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId) == 0
        ) {
            return false;
        }

        if (
            !positionRegistry.positionExists(
                positionId
            )
        ) {
            return false;
        }

        if (
            !compositionRegistry.isActive(
                CompositionOperations.MERGE
            )
        ) {
            return false;
        }

        return capabilityManager.hasCapability(
            positionId,
            CapabilityFlags.MERGEABLE
        );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL COMPOSE CHECK
    //////////////////////////////////////////////////////////////

    function _supportsComposition(
        PositionId positionId
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId) == 0
        ) {
            return false;
        }

        if (
            !positionRegistry.positionExists(
                positionId
            )
        ) {
            return false;
        }

        if (
            !compositionRegistry.isActive(
                CompositionOperations.COMPOSE
            )
        ) {
            return false;
        }

        return capabilityManager.hasCapability(
            positionId,
            CapabilityFlags.COMPOSABLE
        );
    }
}
