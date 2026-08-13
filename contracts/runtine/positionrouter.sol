// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";

/// @title PRC-369 Position Router
/// @author MINTer
/// @notice Resolves the Runtime destination for Position operations.
/// @dev
/// The Router does NOT:
/// - Modify Position identity.
/// - Modify Position runtime.
/// - Execute operations.
/// - Validate economic settlement.
/// - Manage capabilities.
/// - Manage permissions.
///
/// It only maps an operation identifier to its Runtime destination.

contract PositionRouter {

    //////////////////////////////////////////////////////////////
    // OPERATION DESTINATION
    //////////////////////////////////////////////////////////////

    mapping(bytes32 => address) private _destinations;

    //////////////////////////////////////////////////////////////
    // ROUTER AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable routerAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(address authority) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        routerAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER DESTINATION
    //////////////////////////////////////////////////////////////

    function setDestination(
        bytes32 operation,
        address destination
    )
        external
    {
        if (msg.sender != routerAuthority) {
            revert Unauthorized();
        }

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        if (destination == address(0)) {
            revert ZeroAddress();
        }

        _destinations[operation] = destination;
    }

    //////////////////////////////////////////////////////////////
    // REMOVE DESTINATION
    //////////////////////////////////////////////////////////////

    function clearDestination(
        bytes32 operation
    )
        external
    {
        if (msg.sender != routerAuthority) {
            revert Unauthorized();
        }

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        delete _destinations[operation];
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE DESTINATION
    //////////////////////////////////////////////////////////////

    function resolve(
        bytes32 operation
    )
        external
        view
        returns (address destination)
    {
        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        destination = _destinations[operation];

        if (destination == address(0)) {
            revert UnsupportedOperation();
        }
    }

    //////////////////////////////////////////////////////////////
    // CHECK DESTINATION
    //////////////////////////////////////////////////////////////

    function hasDestination(
        bytes32 operation
    )
        external
        view
        returns (bool)
    {
        if (operation == bytes32(0)) {
            return false;
        }

        return _destinations[operation] != address(0);
    }
}
