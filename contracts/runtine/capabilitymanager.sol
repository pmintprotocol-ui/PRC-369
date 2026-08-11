// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/Events.sol";
import "../kernel/CapabilityFlags.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Capability Manager
/// @author MINTer
/// @notice Manages the mutable capability state of PRC-369 Positions.
/// @dev
/// Runtime component responsible for enabling and disabling capabilities.
///
/// CapabilityFlags.sol defines the canonical capability vocabulary.
///
/// PositionRegistry remains the authoritative storage layer for
/// Position identity and Position runtime.
///
/// The CapabilityManager maintains the mutable capability mask
/// independently from immutable PositionIdentity.
contract CapabilityManager {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Position Registry.
    PositionRegistry public immutable registry;

    /// @notice Authority allowed to modify capabilities.
    address public immutable capabilityAuthority;

    /// @notice Active capability mask for each Position.
    mapping(PositionId => CapabilityMask) private _capabilities;

    /// @notice Tracks whether capability state has been initialized.
    mapping(PositionId => bool) private _initialized;


    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Capability Manager.
    /// @param registryAddress Position Registry address.
    /// @param authority Authority allowed to manage capabilities.
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
    // INITIALIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the mutable capability state for a Position.
    /// @dev
    /// The initial capability mask is taken from the immutable
    /// PositionIdentity stored in the Registry.
    ///
    /// @param positionId Position identifier.
    function initializeCapabilities(
        PositionId positionId
    )
        external
    {
        _authorize();

        if (_initialized[positionId]) {
            revert PositionAlreadyRegistered();
        }

        PositionIdentity memory identity =
            registry.getPositionIdentity(positionId);

        _capabilities[positionId] = identity.capabilities;

        _initialized[positionId] = true;
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

        if (!_initialized[positionId]) {
            revert PositionNotFound();
        }

        uint256 currentMask =
            CapabilityMask.unwrap(
                _capabilities[positionId]
            );

        uint256 capabilityMask =
            CapabilityMask.unwrap(capability);

        if ((currentMask & capabilityMask) != 0) {
            revert CapabilityAlreadyEnabled();
        }

        uint256 newMask =
            currentMask | capabilityMask;

        _capabilities[positionId] =
            CapabilityMask.wrap(newMask);

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

        if (!_initialized[positionId]) {
            revert PositionNotFound();
        }

        uint256 currentMask =
            CapabilityMask.unwrap(
                _capabilities[positionId]
            );

        uint256 capabilityMask =
            CapabilityMask.unwrap(capability);

        if ((currentMask & capabilityMask) == 0) {
            revert CapabilityAlreadyDisabled();
        }

        uint256 newMask =
            currentMask & ~capabilityMask;

        _capabilities[positionId] =
            CapabilityMask.wrap(newMask);

        emit CapabilityDisabled(
            positionId,
            capability
        );
    }


    //////////////////////////////////////////////////////////////
    // READ CAPABILITIES
    //////////////////////////////////////////////////////////////

    /// @notice Returns the current active capability mask.
    /// @param positionId Position identifier.
    /// @return capabilities Current capability mask.
    function getCapabilities(
        PositionId positionId
    )
        external
        view
        returns (CapabilityMask capabilities)
    {
        if (!_initialized[positionId]) {
            revert PositionNotFound();
        }

        return _capabilities[positionId];
    }


    //////////////////////////////////////////////////////////////
    // CHECK CAPABILITY
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a capability is currently enabled.
    /// @param positionId Position identifier.
    /// @param capability Capability flag to check.
    /// @return supported True if the capability is enabled.
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

        if (!_initialized[positionId]) {
            return false;
        }

        uint256 currentMask =
            CapabilityMask.unwrap(
                _capabilities[positionId]
            );

        uint256 capabilityMask =
            CapabilityMask.unwrap(capability);

        return (currentMask & capabilityMask) != 0;
    }


    //////////////////////////////////////////////////////////////
    // INITIALIZATION STATUS
    //////////////////////////////////////////////////////////////

    /// @notice Returns whether capability state has been initialized.
    /// @param positionId Position identifier.
    /// @return True if initialized.
    function capabilitiesInitialized(
        PositionId positionId
    )
        external
        view
        returns (bool)
    {
        return _initialized[positionId];
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
