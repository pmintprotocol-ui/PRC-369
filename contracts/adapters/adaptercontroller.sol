// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./IPositionAdapter.sol";
import "./PositionAdapterRegistry.sol";

/// @title PRC-369 Adapter Controller
/// @author MINTer
/// @notice Coordinates authorized execution through registered adapters.
/// @dev
/// The Controller does NOT:
/// - Store Position identity.
/// - Store Position runtime.
/// - Define adapter logic.
/// - Define settlement logic.
/// - Register adapters.
///
/// PositionAdapterRegistry remains the authoritative adapter registry.
///
/// The Controller resolves an active adapter and forwards the operation
/// to that adapter.

contract AdapterController {

    //////////////////////////////////////////////////////////////
    // REGISTRY
    //////////////////////////////////////////////////////////////

    PositionAdapterRegistry public immutable adapterRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable controllerAuthority;

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

        adapterRegistry =
            PositionAdapterRegistry(registryAddress);

        controllerAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // EXECUTE
    //////////////////////////////////////////////////////////////

    function execute(
        PositionId positionId,
        bytes32 operation,
        bytes calldata data
    )
        external
        returns (bytes memory result)
    {
        _authorize();

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        address adapter =
            adapterRegistry.resolveAdapter(
                operation
            );

        if (
            !IPositionAdapter(adapter)
                .supportsPosition(positionId)
        ) {
            revert UnsupportedOperation();
        }

        if (
            !IPositionAdapter(adapter)
                .supportsOperation(
                    positionId,
                    operation
                )
        ) {
            revert UnsupportedOperation();
        }

        result =
            IPositionAdapter(adapter).execute(
                positionId,
                operation,
                data
            );
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE ADAPTER
    //////////////////////////////////////////////////////////////

    function resolveAdapter(
        bytes32 operation
    )
        external
        view
        returns (address adapter)
    {
        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        return adapterRegistry.resolveAdapter(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // SUPPORT CHECK
    //////////////////////////////////////////////////////////////

    function supportsOperation(
        PositionId positionId,
        bytes32 operation
    )
        external
        view
        returns (bool supported)
    {
        if (operation == bytes32(0)) {
            return false;
        }

        address adapter;

        try adapterRegistry.resolveAdapter(
            operation
        )
            returns (address resolvedAdapter)
        {
            adapter = resolvedAdapter;
        }
        catch {
            return false;
        }

        if (
            !IPositionAdapter(adapter)
                .supportsPosition(positionId)
        ) {
            return false;
        }

        return
            IPositionAdapter(adapter)
                .supportsOperation(
                    positionId,
                    operation
                );
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (
            msg.sender != controllerAuthority
        ) {
            revert Unauthorized();
        }
    }
}
