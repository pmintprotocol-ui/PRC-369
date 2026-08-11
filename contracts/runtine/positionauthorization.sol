// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CapabilityFlags.sol";
import "./PositionRegistry.sol";
import "./PositionAccess.sol";
import "./CapabilityManager.sol";
import "./PositionValidator.sol";

/// @title PRC-369 Position Authorization
/// @author MINTer
/// @notice Authorizes specific runtime operations on PRC-369 Positions.
/// @dev
/// PositionAccess answers:
///     "Does this account have access to the Position?"
///
/// PositionAuthorization answers:
///     "Is this account authorized to perform this operation?"
///
/// This contract does NOT:
/// - Store Position identity.
/// - Modify Position runtime.
/// - Execute lifecycle transitions.
/// - Modify capabilities.
/// - Execute economic settlement.

contract PositionAuthorization {

    //////////////////////////////////////////////////////////////
    // MODULES
    //////////////////////////////////////////////////////////////

    PositionRegistry public immutable registry;

    PositionAccess public immutable accessManager;

    CapabilityManager public immutable capabilityManager;

    PositionValidator public immutable validator;

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION OVERRIDES
    //////////////////////////////////////////////////////////////

    mapping(
        PositionId =>
        mapping(
            address =>
            mapping(
                bytes32 => bool
            )
        )
    ) private _authorizedOperations;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address registryAddress,
        address accessManagerAddress,
        address capabilityManagerAddress,
        address validatorAddress
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (accessManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (capabilityManagerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (validatorAddress == address(0)) {
            revert ZeroAddress();
        }

        registry =
            PositionRegistry(registryAddress);

        accessManager =
            PositionAccess(accessManagerAddress);

        capabilityManager =
            CapabilityManager(capabilityManagerAddress);

        validator =
            PositionValidator(validatorAddress);
    }

    //////////////////////////////////////////////////////////////
    // OPERATION AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Grants authorization for a specific operation.
    /// @param positionId Position identifier.
    /// @param account Account receiving authorization.
    /// @param operation Operation identifier.
    function authorizeOperation(
        PositionId positionId,
        address account,
        bytes32 operation
    )
        external
    {
        if (account == address(0)) {
            revert ZeroAddress();
        }

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        if (!accessManager.isAuthorized(
            positionId,
            msg.sender
        )) {
            revert Unauthorized();
        }

        _authorizedOperations[positionId][account][operation] = true;
    }

    //////////////////////////////////////////////////////////////
    // OPERATION REVOCATION
    //////////////////////////////////////////////////////////////

    /// @notice Revokes authorization for a specific operation.
    /// @param positionId Position identifier.
    /// @param account Account losing authorization.
    /// @param operation Operation identifier.
    function revokeOperation(
        PositionId positionId,
        address account,
        bytes32 operation
    )
        external
    {
        if (account == address(0)) {
            revert ZeroAddress();
        }

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        if (!accessManager.isAuthorized(
            positionId,
            msg.sender
        )) {
            revert Unauthorized();
        }

        _authorizedOperations[positionId][account][operation] = false;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an account is authorized for an operation.
    /// @param positionId Position identifier.
    /// @param account Account being checked.
    /// @param operation Operation identifier.
    /// @return authorized True when the operation is authorized.
    function isOperationAuthorized(
        PositionId positionId,
        address account,
        bytes32 operation
    )
        external
        view
        returns (bool authorized)
    {
        if (account == address(0)) {
            return false;
        }

        if (operation == bytes32(0)) {
            return false;
        }

        if (!registry.positionExists(positionId)) {
            return false;
        }

        if (!validator.validate(positionId)) {
            return false;
        }

        return _authorizedOperations[
            positionId
        ][account][operation];
    }

    //////////////////////////////////////////////////////////////
    // FULL AUTHORIZATION CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks access, capability, validation and operation
    ///         authorization together.
    /// @param positionId Position identifier.
    /// @param account Account requesting the operation.
    /// @param capability Required capability.
    /// @param operation Operation identifier.
    /// @return authorized True when all requirements are satisfied.
    function canExecute(
        PositionId positionId,
        address account,
        CapabilityMask capability,
        bytes32 operation
    )
        external
        view
        returns (bool authorized)
    {
        if (account == address(0)) {
            return false;
        }

        if (operation == bytes32(0)) {
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

        if (!_authorizedOperations[
            positionId
        ][account][operation]) {
            return false;
        }

        return true;
    }
}
