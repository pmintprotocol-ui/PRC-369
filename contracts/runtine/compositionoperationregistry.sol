// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/Errors.sol";
import "./CompositionRegistry.sol";

/// @title PRC-369 Composition Operation Registry
/// @author MINTer
/// @notice Registers concrete composition operations involving Positions.
/// @dev
/// CompositionId identifies one concrete Composition.
/// CompositionOperationId identifies the operation type.
///
/// This contract does NOT:
/// - Execute composition.
/// - Modify Positions.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic values.
/// - Create or destroy Positions.
/// - Manage Composition lifecycle state.
///
/// Execution remains the responsibility of Runtime controllers.

contract CompositionOperationRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Concrete Composition operation metadata.
    struct CompositionOperation {
        CompositionOperationId operation;
        bool active;
        bool exists;
    }

    /// @notice Concrete Composition operations.
    mapping(CompositionId => CompositionOperation)
        private _operations;

    //////////////////////////////////////////////////////////////
    // REGISTRY
    //////////////////////////////////////////////////////////////

    /// @notice Registry of supported Composition operation types.
    CompositionRegistry public immutable compositionRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage concrete operations.
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
            CompositionRegistry(
                registryAddress
            );

        operationAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Registers a concrete operation for a Composition.
    /// @param compositionId Unique Composition identifier.
    /// @param operation Composition operation type.
    function registerOperation(
        CompositionId compositionId,
        CompositionOperationId operation
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        _validateOperationId(
            operation
        );

        if (
            _operations[compositionId].exists
        ) {
            revert PositionAlreadyRegistered();
        }

        if (
            !compositionRegistry.isActive(
                operation
            )
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
    // ACTIVATE OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Activates a registered Composition operation.
    /// @param compositionId Composition identifier.
    function activateOperation(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        if (
            !_operations[compositionId].exists
        ) {
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
    // DEACTIVATE OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Deactivates a registered Composition operation.
    /// @param compositionId Composition identifier.
    function deactivateOperation(
        CompositionId compositionId
    )
        external
    {
        _authorize();

        if (
            !_operations[compositionId].exists
        ) {
            revert PositionNotFound();
        }

        _operations[compositionId].active = false;
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the active operation type of a Composition.
    /// @param compositionId Composition identifier.
    /// @return operation Registered Composition operation type.
    function resolveOperation(
        CompositionId compositionId
    )
        external
        view
        returns (
            CompositionOperationId operation
        )
    {
        _validateCompositionId(
            compositionId
        );

        CompositionOperation memory composition =
            _operations[compositionId];

        if (
            !composition.exists
        ) {
            revert UnsupportedOperation();
        }

        if (
            !composition.active
        ) {
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

    /// @notice Checks whether a Composition operation exists.
    /// @param compositionId Composition identifier.
    /// @return exists True when registered.
    function exists(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool
        )
    {
        return
            _operations[compositionId].exists;
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition operation is active.
    /// @param compositionId Composition identifier.
    /// @return active True when active.
    function isActive(
        CompositionId compositionId
    )
        external
        view
        returns (
            bool
        )
    {
        return
            _operations[compositionId].exists &&
            _operations[compositionId].active;
    }

    //////////////////////////////////////////////////////////////
    // OPERATION TYPE
    //////////////////////////////////////////////////////////////

    /// @notice Returns the operation type assigned to a Composition.
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
        if (
            !_operations[compositionId].exists
        ) {
            revert PositionNotFound();
        }

        return
            _operations[compositionId].operation;
    }

    //////////////////////////////////////////////////////////////
    // OPERATION TYPE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Composition has a specific operation.
    /// @param compositionId Composition identifier.
    /// @param operation Operation type being checked.
    /// @return matches True when the operation matches.
    function isOperationType(
        CompositionId compositionId,
        CompositionOperationId operation
    )
        external
        view
        returns (
            bool matches
        )
    {
        if (
            !_operations[compositionId].exists
        ) {
            return false;
        }

        if (
            CompositionOperationId.unwrap(operation)
            == bytes32(0)
        ) {
            return false;
        }

        return
            CompositionOperationId.unwrap(
                _operations[compositionId].operation
            )
            ==
            CompositionOperationId.unwrap(
                operation
            );
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateCompositionId(
        CompositionId compositionId
    )
        internal
        pure
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }
    }

    function _validateOperationId(
        CompositionOperationId operation
    )
        internal
        pure
    {
        if (
            CompositionOperationId.unwrap(operation)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (
            msg.sender != operationAuthority
        ) {
            revert Unauthorized();
        }
    }
}
