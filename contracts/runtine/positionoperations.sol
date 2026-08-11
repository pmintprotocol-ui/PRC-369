// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CapabilityFlags.sol";
import "./PositionRegistry.sol";
import "./CapabilityManager.sol";
import "./PositionAccess.sol";
import "./PositionValidator.sol";

/// @title PRC-369 Position Operations
/// @author MINTer
/// @notice Validates operational requests against Position capabilities.
/// @dev
/// Runtime component responsible for determining whether a Position
/// supports a requested operation.
///
/// This contract does NOT:
/// - Modify Position identity.
/// - Modify Position runtime.
/// - Execute lifecycle transitions.
/// - Modify capability state.
/// - Execute economic settlement.
///
/// It only validates whether an operation is permitted by the
/// current Position capability mask.

contract PositionOperations {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    PositionRegistry public immutable registry;

    CapabilityManager public immutable capabilityManager;

    PositionAccess public immutable accessManager;

    PositionValidator public immutable validator;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address registryAddress,
        address capabilityManagerAddress,
        address accessManagerAddress,
        address validatorAddress
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (capabilityManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (accessManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (validatorAddress == address(0)) {
            revert ZeroAddress();
        }

        registry = PositionRegistry(registryAddress);

        capabilityManager =
            CapabilityManager(capabilityManagerAddress);

        accessManager =
            PositionAccess(accessManagerAddress);

        validator =
            PositionValidator(validatorAddress);
    }

    //////////////////////////////////////////////////////////////
    // OPERATION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an account may perform an operation
    ///         on a Position.
    /// @param positionId Position identifier.
    /// @param account Account requesting the operation.
    /// @param capability Required capability.
    /// @return allowed True when the operation is permitted.
    function canOperate(
        PositionId positionId,
        address account,
        CapabilityMask capability
    )
        external
        view
        returns (bool allowed)
    {
        if (account == address(0)) {
            return false;
        }

        if (!registry.positionExists(positionId)) {
            return false;
        }

        if (!validator.validate(positionId)) {
            return false;
        }

        if (!accessManager.isAuthorized(
            positionId,
            account
        )) {
            return false;
        }

        if (!capabilityManager.hasCapability(
            positionId,
            capability
        )) {
            return false;
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // CAPABILITY VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position supports a capability.
    /// @param positionId Position identifier.
    /// @param capability Capability being requested.
    /// @return supported True when the capability is active.
    function supportsOperation(
        PositionId positionId,
        CapabilityMask capability
    )
        external
        view
        returns (bool supported)
    {
        if (!registry.positionExists(positionId)) {
            return false;
        }

        if (!validator.validate(positionId)) {
            return false;
        }

        return capabilityManager.hasCapability(
            positionId,
            capability
        );
    }

    //////////////////////////////////////////////////////////////
    // ACCESS VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an account has access to a Position.
    /// @param positionId Position identifier.
    /// @param account Account being checked.
    /// @return authorized True when access is granted.
    function hasOperationalAccess(
        PositionId positionId,
        address account
    )
        external
        view
        returns (bool authorized)
    {
        if (!registry.positionExists(positionId)) {
            return false;
        }

        return accessManager.isAuthorized(
            positionId,
            account
        );
    }
}
