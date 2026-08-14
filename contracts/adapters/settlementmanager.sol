// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./SettlementRegistry.sol";

/// @title PRC-369 Settlement Manager
/// @author MINTer
/// @notice Administrative manager for registered settlement implementations.
/// @dev
/// The Manager does NOT:
/// - Execute settlement.
/// - Store Position state.
/// - Define economic settlement rules.
/// - Hold settlement balances.
/// - Replace SettlementRegistry.
///
/// SettlementRegistry remains the authoritative source of settlement
/// implementation configuration.
///
/// SettlementManager only coordinates administrative actions.

contract SettlementManager {

    //////////////////////////////////////////////////////////////
    // REGISTRY
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Settlement Registry.
    SettlementRegistry public immutable registry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage settlements.
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
            SettlementRegistry(registryAddress);

        managerAuthority =
            authority;
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

        registry.registerSettlement(
            settlement
        );
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

        registry.activateSettlement(
            settlement
        );
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

        registry.deactivateSettlement(
            settlement
        );
    }

    //////////////////////////////////////////////////////////////
    // ASSIGN OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Assigns a settlement implementation to an operation.
    /// @param operation Operation identifier.
    /// @param settlement Settlement implementation address.
    function assignOperation(
        bytes32 operation,
        address settlement
    )
        external
    {
        _authorize();

        registry.setSettlement(
            operation,
            settlement
        );
    }

    //////////////////////////////////////////////////////////////
    // CLEAR OPERATION
    //////////////////////////////////////////////////////////////

    /// @notice Removes a settlement operation assignment.
    /// @param operation Operation identifier.
    function clearOperation(
        bytes32 operation
    )
        external
    {
        _authorize();

        registry.clearSettlement(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // REGISTERED STATUS
    //////////////////////////////////////////////////////////////

    /// @notice Returns whether a settlement implementation is registered.
    /// @param settlement Settlement implementation address.
    /// @return registered True if registered.
    function isRegistered(
        address settlement
    )
        external
        view
        returns (bool registered)
    {
        return registry.isRegistered(
            settlement
        );
    }

    //////////////////////////////////////////////////////////////
    // ACTIVE STATUS
    //////////////////////////////////////////////////////////////

    /// @notice Returns whether a settlement implementation is active.
    /// @param settlement Settlement implementation address.
    /// @return active True if active.
    function isActive(
        address settlement
    )
        external
        view
        returns (bool active)
    {
        return registry.isActive(
            settlement
        );
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the settlement implementation assigned
    /// to an operation.
    /// @param operation Operation identifier.
    /// @return settlement Settlement implementation address.
    function resolveSettlement(
        bytes32 operation
    )
        external
        view
        returns (address settlement)
    {
        return registry.resolveSettlement(
            operation
        );
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Settlement Manager authority.
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
