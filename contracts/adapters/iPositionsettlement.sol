// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";

/// @title PRC-369 Position Settlement Interface
/// @author MINTer
/// @notice Defines the canonical interface for settlement systems.
/// @dev
/// Settlement operates on Position economic states without redefining
/// the canonical Position identity.
///
/// This interface does NOT:
/// - Define token economics.
/// - Define protocol-specific settlement rules.
/// - Store Position state.
/// - Transfer assets directly.
/// - Define adapters for a specific external protocol.
///
/// Concrete settlement implementations may be used by adapters.

interface IPositionSettlement {

    //////////////////////////////////////////////////////////////
    // SETTLEMENT SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Determines whether a Position can be settled.
    /// @param positionId Position identifier.
    /// @return supported True if settlement is supported.
    function supportsSettlement(
        PositionId positionId
    )
        external
        view
        returns (bool supported);

    //////////////////////////////////////////////////////////////
    // SETTLEMENT PREVIEW
    //////////////////////////////////////////////////////////////

    /// @notice Previews the result of a settlement operation.
    /// @param positionId Position identifier.
    /// @param data Settlement-specific parameters.
    /// @return result Settlement preview data.
    function previewSettlement(
        PositionId positionId,
        bytes calldata data
    )
        external
        view
        returns (bytes memory result);

    //////////////////////////////////////////////////////////////
    // SETTLEMENT EXECUTION
    //////////////////////////////////////////////////////////////

    /// @notice Executes settlement for a Position.
    /// @param positionId Position identifier.
    /// @param data Settlement-specific parameters.
    /// @return result Settlement execution result.
    function settle(
        PositionId positionId,
        bytes calldata data
    )
        external
        returns (bytes memory result);
}
