// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/Events.sol";
import "../kernel/CapabilityFlags.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Capability Manager
/// @author MINTer
/// @notice Manages the capabilities assigned to PRC-369 Positions.
/// @dev
/// Runtime component responsible for enabling and disabling capabilities.
///
/// The CapabilityManager does NOT define capabilities.
/// CapabilityFlags.sol defines the canonical capability vocabulary.
///
/// The Registry remains the authoritative storage layer.
contract CapabilityManager {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Position Registry used as the authoritative storage layer.
    PositionRegistry public immutable registry;

    /// @notice Authority allowed to modify Position capabilities.
    address public immutable capabilityAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Capability Manager.
    /// @param registryAddress Address of the Position Registry.
    /// @param authority Address authorized to manage capabilities.
    constructor(
        address registryAddress,
        address authority
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registry = PositionRegistry(registryAddress);
        capabilityAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // ENABLE CAPABILITY
    //////////////////////////////////////////////////////////////

    /// @notice Enables a capability for a Position.
    /// @param positionId Position identifier.
    /// @param capability Capability flag to enable.
    function enableCapability(
        PositionId positionId,
        CapabilityMask capability
    )
        external
    {
        _authorize();

        if (CapabilityMask.unwrap(capability) == 0) {
            revert ZeroValue();
        }

        PositionDefinition memory definition =
            registry.getPositionDefinition(positionId);

        uint256 currentMask =
            CapabilityMask.unwrap(definition.capabilities);

        uint256 capabilityMask =
            CapabilityMask.unwrap(capability);

        if ((currentMask & capabilityMask) != 0) {
            revert CapabilityAlreadyEnabled();
        }

        CapabilityMask newCapabilities =
            CapabilityMask.wrap(
                currentMask | capabilityMask
            );

        registry.updateCapabilities(
            positionId,
            newCapabilities
        );

        emit CapabilityEnabled(
            positionId,
            capability
        );
    }

    //////////////////////////////////////////////////////////////
    // DISABLE CAPABILITY
    //////////////////////////////////////////////////////////////

    /// @notice Disables a capability for a Position.
    /// @param positionId Position identifier.
    /// @param capability Capability flag to disable.
    function disableCapability(
        PositionId positionId,
        CapabilityMask capability
    )
        external
    {
        _authorize();

        if (CapabilityMask.unwrap(capability) == 0) {
            revert ZeroValue();
        }

        PositionDefinition memory definition =
            registry.getPositionDefinition(positionId);

        uint256 currentMask =
            CapabilityMask.unwrap(definition.capabilities);

        uint256 capabilityMask =
            CapabilityMask.unwrap(capability);

        if ((currentMask & capabilityMask) == 0) {
            revert CapabilityAlreadyDisabled();
        }

        CapabilityMask newCapabilities =
            CapabilityMask.wrap(
                currentMask & ~capabilityMask
            );

        registry.updateCapabilities(
            positionId,
            newCapabilities
        );

        emit CapabilityDisabled(
            positionId,
            capability
        );
    }

    //////////////////////////////////////////////////////////////
    // READ CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Returns the complete capability mask of a Position.
    /// @param positionId Position identifier.
    /// @return capabilities Current capability mask.
    function getCapabilities(
        PositionId positionId
    )
        external
        view
        returns (CapabilityMask capabilities)
    {
        PositionDefinition memory definition =
            registry.getPositionDefinition(positionId);

        return definition.capabilities;
    }

    //////////////////////////////////////////////////////////////
    // CHECK CAPABILITY
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position supports a capability.
    /// @param positionId Position identifier.
    /// @param capability Capability flag to check.
    /// @return supported True when the capability is enabled.
    function hasCapability(
        PositionId positionId,
        CapabilityMask capability
    )
        external
        view
        returns (bool supported)
    {
        if (CapabilityMask.unwrap(capability) == 0) {
            return false;
        }

        PositionDefinition memory definition =
            registry.getPositionDefinition(positionId);

        uint256 currentMask =
            CapabilityMask.unwrap(definition.capabilities);

        uint256 capabilityMask =
            CapabilityMask.unwrap(capability);

        return (currentMask & capabilityMask) != 0;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Capability Manager authority.
    function _authorize()
        internal
        view
    {
        if (msg.sender != capabilityAuthority) {
            revert Unauthorized();
        }
    }
}
