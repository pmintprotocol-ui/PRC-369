// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./PositionAdapterRegistry.sol";

/// @title PRC-369 Adapter Manager
/// @author MINTer
/// @notice Administrative controller for registered PRC-369 adapters.
/// @dev
/// The Manager does NOT:
/// - Execute adapter operations.
/// - Store Position identity.
/// - Store Position runtime.
/// - Define settlement logic.
/// - Replace PositionAdapterRegistry.
///
/// It coordinates the administrative activation state of adapters
/// through PositionAdapterRegistry.

contract AdapterManager {

    //////////////////////////////////////////////////////////////
    // REGISTRY
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Adapter Registry.
    PositionAdapterRegistry public immutable registry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage adapters.
    address public immutable managerAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

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

        registry =
            PositionAdapterRegistry(registryAddress);

        managerAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER
    //////////////////////////////////////////////////////////////

    /// @notice Registers a new adapter.
    /// @param adapter Adapter contract address.
    function registerAdapter(
        address adapter
    )
        external
    {
        _authorize();

        registry.registerAdapter(adapter);
    }

    //////////////////////////////////////////////////////////////
    // ACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Activates a registered adapter.
    /// @param adapter Adapter contract address.
    function activateAdapter(
        address adapter
    )
        external
    {
        _authorize();

        registry.activateAdapter(adapter);
    }

    //////////////////////////////////////////////////////////////
    // DEACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Deactivates a registered adapter.
    /// @param adapter Adapter contract address.
    function deactivateAdapter(
        address adapter
    )
        external
    {
        _authorize();

        registry.deactivateAdapter(adapter);
    }

    //////////////////////////////////////////////////////////////
    // ASSIGN OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Assigns an operation to an adapter.
    /// @param operation Operation identifier.
    /// @param adapter Adapter contract address.
    function assignOperation(
        bytes32 operation,
        address adapter
    )
        external
    {
        _authorize();

        registry.setAdapter(
            operation,
            adapter
        );
    }

    //////////////////////////////////////////////////////////////
    // CLEAR OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Removes an operation-to-adapter assignment.
    /// @param operation Operation identifier.
    function clearOperation(
        bytes32 operation
    )
        external
    {
        _authorize();

        registry.clearAdapter(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // STATUS
    //////////////////////////////////////////////////////////////

    /// @notice Returns whether an adapter is registered.
    /// @param adapter Adapter contract address.
    /// @return registered True if registered.
    function isRegistered(
        address adapter
    )
        external
        view
        returns (bool registered)
    {
        return registry.isRegistered(adapter);
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE STATUS
    //////////////////////////////////////////////////////////////

    /// @notice Returns whether an adapter is active.
    /// @param adapter Adapter contract address.
    /// @return active True if active.
    function isActive(
        address adapter
    )
        external
        view
        returns (bool active)
    {
        return registry.isActive(adapter);
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the adapter assigned to an operation.
    /// @param operation Operation identifier.
    /// @return adapter Adapter address.
    function resolveAdapter(
        bytes32 operation
    )
        external
        view
        returns (address adapter)
    {
        return registry.resolveAdapter(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Manager authority.
    function _authorize()
        internal
        view
    {
        if (
            msg.sender != managerAuthority
        ) {
            revert Unauthorized();
        }
    }
}
