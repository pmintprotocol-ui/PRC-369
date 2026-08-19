// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "./CompositionRegistry.sol";

/// @title PRC-369 Composition Operation Registry
/// @author MINTer
/// @notice Registers concrete composition operations involving Positions.
/// @dev
/// This registry records the existence and lifecycle of composition
/// operations.
///
/// It does NOT:
/// - Execute composition.
/// - Modify Positions.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic values.
/// - Create or destroy Positions.
///
/// Execution remains the responsibility of runtime controllers.

contract CompositionOperationRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Composition operation metadata.
    struct CompositionOperation {
        CompositionOperationId operation;
        bool active;
        bool exists;
    }

    /// @notice Registered composition operations.
    mapping(CompositionId => CompositionOperation)
        private _operations;

    //////////////////////////////////////////////////////////////
    // REGISTRY
    //////////////////////////////////////////////////////////////

    /// @notice Registry controlling supported operation types.
    CompositionRegistry public immutable compositionRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to register composition operations.
    address public immutable operationAuthority;

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

        compositionRegistry =
            CompositionRegistry(registryAddress);

        operationAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Registers a concrete composition operation.
    /// @param compositionId Unique composition identifier.
    /// @param operation Composition operation type.
    function registerOperation(
        CompositionId compositionId,
        CompositionOperationId operation
    )
        external
    {
        _authorize();

        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (
            CompositionOperationId.unwrap(operation)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }

        if (_operations[compositionId].exists) {
            revert PositionAlreadyRegistered();
        }

        if (
            !compositionRegistry.isActive(operation)
        ) {
            revert UnsupportedOperation();
        }

        _operations[compositionId] =
            CompositionOperation({
                operation: operation,
                active: true,
                exists: true
            });
    }

    //////////////////////////////////////////////////////////////
    // ACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Activates a registered composition operation.
    /// @param compositionId Composition identifier.
    function activateOperation(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        if (!_operations[compositionId].exists) {
            revert PositionNotFound();
        }

        CompositionOperation storage operation =
            _operations[compositionId];

        if (
            !compositionRegistry.isActive(
                operation.operation
            )
        ) {
            revert UnsupportedOperation();
        }

        operation.active = true;
    }

    //////////////////////////////////////////////////////////////
    // DEACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Deactivates a registered composition operation.
    /// @param compositionId Composition identifier.
    function deactivateOperation(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        if (!_operations[compositionId].exists) {
            revert PositionNotFound();
        }

        _operations[compositionId].active = false;
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE
    //////////////////////////////////////////////////////////////

    /// @notice Resolves an active composition operation.
    /// @param compositionId Composition identifier.
    /// @return operation Composition operation type.
    function resolveOperation(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionOperationId operation
        )
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }

        CompositionOperation memory composition =
            _operations[compositionId];

        if (!composition.exists) {
            revert UnsupportedOperation();
        }

        if (!composition.active) {
            revert UnsupportedOperation();
        }

        if (
            !compositionRegistry.isActive(
                composition.operation
            )
        ) {
            revert UnsupportedOperation();
        }

        return composition.operation;
    }

    //////////////////////////////////////////////////////////////
    // EXISTENCE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a composition operation exists.
    /// @param compositionId Composition identifier.
    /// @return exists True if registered.
    function exists(
        CompositionId compositionId
    )
        external
        view
        returns (bool)
    {
        return _operations[compositionId].exists;
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a composition operation is active.
    /// @param compositionId Composition identifier.
    /// @return active True if active.
    function isActive(
        CompositionId compositionId
    )
        external
        view
        returns (bool)
    {
        return
            _operations[compositionId].exists &&
            _operations[compositionId].active;
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
        if (!_operations[compositionId].exists) {
            revert PositionNotFound();
        }

        return _operations[compositionId].operation;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates operation registry authority.
    function _authorize()
        internal
        view
    {
        if (msg.sender != operationAuthority) {
            revert Unauthorized();
        }
    }
}
