// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/Errors.sol";

/// @title PRC-369 Composition Registry
/// @author MINTer
/// @notice Registry for PRC-369 composition operation types.
/// @dev
/// The Registry is the authoritative source for enabled composition
/// operation identifiers.
///
/// It does NOT:
/// - Execute composition.
/// - Modify Positions.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic values.
/// - Enforce split or merge rules.
///
/// Runtime controllers are responsible for execution.

contract CompositionRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Registered composition operations.
    mapping(CompositionOperationId => bool) private _registered;

    /// @notice Active composition operations.
    mapping(CompositionOperationId => bool) private _active;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage composition operations.
    address public immutable compositionAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition Registry.
    /// @param authority Authority allowed to manage operations.
    constructor(
        address authority
    ) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        compositionAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER
    //////////////////////////////////////////////////////////////

    /// @notice Registers a composition operation.
    /// @param operation Composition operation identifier.
    function registerOperation(
        CompositionOperationId operation
    )
        external
    {
        _authorize();

        if (
            CompositionOperationId.unwrap(operation)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (_registered[operation]) {
            revert PositionAlreadyRegistered();
        }

        _registered[operation] = true;
        _active[operation] = true;
    }

    //////////////////////////////////////////////////////////////
    // ACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Activates a registered composition operation.
    /// @param operation Composition operation identifier.
    function activateOperation(
        CompositionOperationId operation
    )
        external
    {
        _authorize();

        if (!_registered[operation]) {
            revert PositionNotFound();
        }

        _active[operation] = true;
    }

    //////////////////////////////////////////////////////////////
    // DEACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Deactivates a registered composition operation.
    /// @param operation Composition operation identifier.
    function deactivateOperation(
        CompositionOperationId operation
    )
        external
    {
        _authorize();

        if (!_registered[operation]) {
            revert PositionNotFound();
        }

        _active[operation] = false;
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE
    //////////////////////////////////////////////////////////////

    /// @notice Resolves whether an operation is currently active.
    /// @param operation Composition operation identifier.
    /// @return active True if the operation is registered and active.
    function resolveOperation(
        CompositionOperationId operation
    )
        external
        view
        returns (bool active)
    {
        if (
            CompositionOperationId.unwrap(operation)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (!_registered[operation]) {
            revert UnsupportedOperation();
        }

        if (!_active[operation]) {
            revert UnsupportedOperation();
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // REGISTERED CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an operation is registered.
    /// @param operation Composition operation identifier.
    /// @return registered True if registered.
    function isRegistered(
        CompositionOperationId operation
    )
        external
        view
        returns (bool registered)
    {
        return _registered[operation];
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an operation is active.
    /// @param operation Composition operation identifier.
    /// @return active True if active.
    function isActive(
        CompositionOperationId operation
    )
        external
        view
        returns (bool active)
    {
        return _active[operation];
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Composition Registry authority.
    function _authorize()
        internal
        view
    {
        if (msg.sender != compositionAuthority) {
            revert Unauthorized();
        }
    }
}
