// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./IPositionSettlement.sol";

/// @title PRC-369 Settlement Registry
/// @author MINTer
/// @notice Registry for PRC-369 settlement implementations.
/// @dev
/// The Registry is the authoritative source for settlement
/// implementations.
///
/// It does NOT:
/// - Execute settlement.
/// - Store Position state.
/// - Define economic rules.
/// - Modify Position identity.
/// - Perform asset transfers.
///
/// It only registers, activates, deactivates and resolves
/// settlement implementations.

contract SettlementRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Registered settlement implementations.
    mapping(address => bool) private _registered;

    /// @notice Active settlement implementations.
    mapping(address => bool) private _active;

    /// @notice Settlement implementation assigned to an operation.
    mapping(bytes32 => address) private _settlements;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage settlements.
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
    // REGISTER
    //////////////////////////////////////////////////////////////

    /// @notice Registers a settlement implementation.
    /// @param settlement Settlement implementation address.
    function registerSettlement(
        address settlement
    )
        external
    {
        _authorize();

        if (settlement == address(0)) {
            revert ZeroAddress();
        }

        if (_registered[settlement]) {
            revert PositionAlreadyRegistered();
        }

        _registered[settlement] = true;
        _active[settlement] = true;
    }

    //////////////////////////////////////////////////////////////
    // ACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Activates a registered settlement implementation.
    /// @param settlement Settlement implementation address.
    function activateSettlement(
        address settlement
    )
        external
    {
        _authorize();

        if (!_registered[settlement]) {
            revert PositionNotFound();
        }

        _active[settlement] = true;
    }

    //////////////////////////////////////////////////////////////
    // DEACTIVATE
    //////////////////////////////////////////////////////////////

    /// @notice Deactivates a registered settlement implementation.
    /// @param settlement Settlement implementation address.
    function deactivateSettlement(
        address settlement
    )
        external
    {
        _authorize();

        if (!_registered[settlement]) {
            revert PositionNotFound();
        }

        _active[settlement] = false;
    }

    //////////////////////////////////////////////////////////////
    // ASSIGN OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Assigns a settlement implementation to an operation.
    /// @param operation Operation identifier.
    /// @param settlement Settlement implementation address.
    function setSettlement(
        bytes32 operation,
        address settlement
    )
        external
    {
        _authorize();

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        if (!_registered[settlement]) {
            revert PositionNotFound();
        }

        if (!_active[settlement]) {
            revert Unauthorized();
        }

        _settlements[operation] = settlement;
    }

    //////////////////////////////////////////////////////////////
    // CLEAR OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Removes the settlement assigned to an operation.
    /// @param operation Operation identifier.
    function clearSettlement(
        bytes32 operation
    )
        external
    {
        _authorize();

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        delete _settlements[operation];
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the active settlement implementation.
    /// @param operation Operation identifier.
    /// @return settlement Active settlement implementation.
    function resolveSettlement(
        bytes32 operation
    )
        external
        view
        returns (address settlement)
    {
        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        settlement = _settlements[operation];

        if (settlement == address(0)) {
            revert UnsupportedOperation();
        }

        if (!_active[settlement]) {
            revert UnsupportedOperation();
        }
    }

    //////////////////////////////////////////////////////////////
    // REGISTERED CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a settlement implementation is registered.
    /// @param settlement Settlement implementation address.
    /// @return registered True if registered.
    function isRegistered(
        address settlement
    )
        external
        view
        returns (bool registered)
    {
        return _registered[settlement];
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a settlement implementation is active.
    /// @param settlement Settlement implementation address.
    /// @return active True if active.
    function isActive(
        address settlement
    )
        external
        view
        returns (bool active)
    {
        return _active[settlement];
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates registry authority.
    function _authorize()
        internal
        view
    {
        if (msg.sender != registryAuthority) {
            revert Unauthorized();
        }
    }
}
