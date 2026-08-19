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
/// @notice Coordinates structural composition operations for Positions.
/// @dev
/// This first implementation validates composition permissions and
/// operation availability without performing economic transformations.
///
/// It does NOT:
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic values.
/// - Create or destroy economic value.
/// - Execute settlement.
/// - Modify Position identity.
///
/// Economic composition rules will be introduced by later runtime layers.

contract PositionCompositionManager {

    //////////////////////////////////////////////////////////////
    // REGISTRIES
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Position Registry.
    PositionRegistry public immutable positionRegistry;

    /// @notice Capability Manager.
    CapabilityManager public immutable capabilityManager;

    /// @notice Composition Registry.
    CompositionRegistry public immutable compositionRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to execute composition operations.
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
            CapabilityManager(capabilityManagerAddress);

        compositionRegistry =
            CompositionRegistry(compositionRegistryAddress);

        compositionAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // SPLIT SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position can participate in a split.
    /// @param positionId Position identifier.
    /// @return supported True if split is currently supported.
    function supportsSplit(
        PositionId positionId
    )
        external
        view
        returns (bool supported)
    {
        if (
            PositionId.unwrap(positionId)
            == 0
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

        return
            capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.SPLITTABLE
            );
    }

    //////////////////////////////////////////////////////////////
    // MERGE SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position can participate in a merge.
    /// @param positionId Position identifier.
    /// @return supported True if merge is currently supported.
    function supportsMerge(
        PositionId positionId
    )
        external
        view
        returns (bool supported)
    {
        if (
            PositionId.unwrap(positionId)
            == 0
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

        return
            capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.MERGEABLE
            );
    }

    //////////////////////////////////////////////////////////////
    // COMPOSE SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position can participate in composition.
    /// @param positionId Position identifier.
    /// @return supported True if composition is currently supported.
    function supportsComposition(
        PositionId positionId
    )
        external
        view
        returns (bool supported)
    {
        if (
            PositionId.unwrap(positionId)
            == 0
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

        return
            capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.COMPOSABLE
            );
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE SPLIT
    //////////////////////////////////////////////////////////////

    /// @notice Validates that a Position may be split.
    /// @param positionId Position identifier.
    function validateSplit(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (
            !supportsSplitInternal(
                positionId
            )
        ) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE MERGE
    //////////////////////////////////////////////////////////////

    /// @notice Validates that a Position may participate in a merge.
    /// @param positionId Position identifier.
    function validateMerge(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (
            !supportsMergeInternal(
                positionId
            )
        ) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSITION
    //////////////////////////////////////////////////////////////

    /// @notice Validates that a Position may participate in composition.
    /// @param positionId Position identifier.
    function validateComposition(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (
            !supportsCompositionInternal(
                positionId
            )
        ) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL SUPPORT CHECKS
    //////////////////////////////////////////////////////////////

    function supportsSplitInternal(
        PositionId positionId
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId)
            == 0
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

        return
            capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.SPLITTABLE
            );
    }

    function supportsMergeInternal(
        PositionId positionId
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId)
            == 0
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

        return
            capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.MERGEABLE
            );
    }

    function supportsCompositionInternal(
        PositionId positionId
    )
        internal
        view
        returns (bool)
    {
        if (
            PositionId.unwrap(positionId)
            == 0
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

        return
            capabilityManager.hasCapability(
                positionId,
                CapabilityFlags.COMPOSABLE
            );
    }
}
