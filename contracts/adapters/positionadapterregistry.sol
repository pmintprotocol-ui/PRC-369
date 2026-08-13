// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./IPositionAdapter.sol";

/// @title PRC-369 Position Adapter Registry
/// @author MINTer
/// @notice Registry for PRC-369 external Position adapters.
/// @dev
/// This contract is the authoritative registry of adapters.
///
/// It does NOT:
/// - Execute adapters.
/// - Modify Position identity.
/// - Modify Position runtime.
/// - Execute settlement.
/// - Define adapter-specific economic logic.
///
/// It only registers, activates and resolves adapters.

contract PositionAdapterRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    mapping(bytes32 => address) private _adapters;

    mapping(address => bool) private _registered;

    mapping(address => bool) private _active;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable registryAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(address authority) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registryAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER ADAPTER
    //////////////////////////////////////////////////////////////

    function registerAdapter(
        address adapter
    )
        external
    {
        _authorize();

        if (adapter == address(0)) {
            revert ZeroAddress();
        }

        if (_registered[adapter]) {
            revert PositionAlreadyRegistered();
        }

        _registered[adapter] = true;
        _active[adapter] = true;
    }

    //////////////////////////////////////////////////////////////
    // ACTIVATE ADAPTER
    //////////////////////////////////////////////////////////////

    function activateAdapter(
        address adapter
    )
        external
    {
        _authorize();

        if (!_registered[adapter]) {
            revert PositionNotFound();
        }

        _active[adapter] = true;
    }

    //////////////////////////////////////////////////////////////
    // DEACTIVATE ADAPTER
    //////////////////////////////////////////////////////////////

    function deactivateAdapter(
        address adapter
    )
        external
    {
        _authorize();

        if (!_registered[adapter]) {
            revert PositionNotFound();
        }

        _active[adapter] = false;
    }

    //////////////////////////////////////////////////////////////
    // ASSIGN OPERATION
    //////////////////////////////////////////////////////////////

    function setAdapter(
        bytes32 operation,
        address adapter
    )
        external
    {
        _authorize();

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        if (!_registered[adapter]) {
            revert PositionNotFound();
        }

        if (!_active[adapter]) {
            revert Unauthorized();
        }

        _adapters[operation] = adapter;
    }

    //////////////////////////////////////////////////////////////
    // CLEAR OPERATION
    //////////////////////////////////////////////////////////////

    function clearAdapter(
        bytes32 operation
    )
        external
    {
        _authorize();

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        delete _adapters[operation];
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

        adapter = _adapters[operation];

        if (adapter == address(0)) {
            revert UnsupportedOperation();
        }

        if (!_active[adapter]) {
            revert UnsupportedOperation();
        }
    }

    //////////////////////////////////////////////////////////////
    // REGISTERED CHECK
    //////////////////////////////////////////////////////////////

    function isRegistered(
        address adapter
    )
        external
        view
        returns (bool registered)
    {
        return _registered[adapter];
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE CHECK
    //////////////////////////////////////////////////////////////

    function isActive(
        address adapter
    )
        external
        view
        returns (bool active)
    {
        return _active[adapter];
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (msg.sender != registryAuthority) {
            revert Unauthorized();
        }
    }
}
