// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./PositionRegistry.sol";
import "./PositionLifecycle.sol";
import "./CapabilityManager.sol";
import "./PositionAccess.sol";
import "./PositionValidator.sol";

/// @title PRC-369 Runtime Controller
/// @author MINTer
/// @notice Coordinates the PRC-369 Runtime modules.
/// @dev
/// The Runtime Controller does not become the authority of the individual
/// modules. It provides a unified coordination layer while preserving the
/// separation of responsibilities between Registry, Lifecycle, Capabilities,
/// Access, and Validation.

contract RuntimeController {

    //////////////////////////////////////////////////////////////
    // MODULES
    //////////////////////////////////////////////////////////////

    PositionRegistry public immutable registry;

    PositionLifecycle public immutable lifecycle;

    CapabilityManager public immutable capabilityManager;

    PositionAccess public immutable accessManager;

    PositionValidator public immutable validator;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable controllerAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address registryAddress,
        address lifecycleAddress,
        address capabilityManagerAddress,
        address accessManagerAddress,
        address validatorAddress,
        address authority
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (lifecycleAddress == address(0)) {
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

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registry = PositionRegistry(registryAddress);

        lifecycle = PositionLifecycle(lifecycleAddress);

        capabilityManager =
            CapabilityManager(capabilityManagerAddress);

        accessManager =
            PositionAccess(accessManagerAddress);

        validator =
            PositionValidator(validatorAddress);

        controllerAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // POSITION STATUS
    //////////////////////////////////////////////////////////////

    function positionStatus(
        PositionId positionId
    )
        external
        view
        returns (
            bool exists,
            bool valid
        )
    {
        exists = registry.positionExists(positionId);

        if (!exists) {
            return (false, false);
        }

        valid = validator.validate(positionId);
    }

    //////////////////////////////////////////////////////////////
    // ACCESS STATUS
    //////////////////////////////////////////////////////////////

    function positionAccess(
        PositionId positionId,
        address account
    )
        external
        view
        returns (bool)
    {
        return accessManager.isAuthorized(
            positionId,
            account
        );
    }

    //////////////////////////////////////////////////////////////
    // CAPABILITY STATUS
    //////////////////////////////////////////////////////////////

    function positionCapability(
        PositionId positionId,
        CapabilityMask capability
    )
        external
        view
        returns (bool)
    {
        return capabilityManager.hasCapability(
            positionId,
            capability
        );
    }

    //////////////////////////////////////////////////////////////
    // VALIDATION
    //////////////////////////////////////////////////////////////

    function isPositionValid(
        PositionId positionId
    )
        external
        view
        returns (bool)
    {
        return validator.validate(positionId);
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (msg.sender != controllerAuthority) {
            revert Unauthorized();
        }
    }
}
