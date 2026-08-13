// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";

/// @title PRC-369 Position Adapter Interface
/// @author MINTer
/// @notice Canonical interface for external Position adapters.
/// @dev
/// Adapters connect PRC-369 Positions with external protocols,
/// markets, vaults, settlement systems or other execution environments.
///
/// The Adapter does NOT own the canonical Position identity.
/// The PRC-369 Runtime remains responsible for Position semantics.
///
/// Adapters MUST NOT redefine Kernel types.

interface IPositionAdapter {

    //////////////////////////////////////////////////////////////
    // POSITION SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Determines whether this Adapter supports a Position.
    /// @param positionId Position identifier.
    /// @return supported True when the Position is supported.
    function supportsPosition(
        PositionId positionId
    )
        external
        view
        returns (bool supported);

    //////////////////////////////////////////////////////////////
    // OPERATION SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Determines whether this Adapter supports an operation.
    /// @param positionId Position identifier.
    /// @param operation Operation identifier.
    /// @return supported True when supported.
    function supportsOperation(
        PositionId positionId,
        bytes32 operation
    )
        external
        view
        returns (bool supported);

    //////////////////////////////////////////////////////////////
    // EXECUTION
    //////////////////////////////////////////////////////////////

    /// @notice Executes an operation against the external system.
    /// @param positionId Position identifier.
    /// @param operation Operation identifier.
    /// @param data Operation-specific data.
    /// @return result Adapter-specific execution result.
    function execute(
        PositionId positionId,
        bytes32 operation,
        bytes calldata data
    )
        external
        returns (bytes memory result);
}
