// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./IPositionSettlement.sol";

/// @title PRC-369 Position Settlement
/// @author MINTer
/// @notice Base settlement implementation for PRC-369 Positions.
/// @dev
/// This contract provides the first canonical settlement implementation.
///
/// It does NOT:
/// - Transfer assets.
/// - Modify balances.
/// - Calculate protocol-specific economics.
/// - Execute swaps.
/// - Perform token accounting.
///
/// It only validates settlement support and returns the supplied
/// settlement data as the execution result.
///
/// Economic settlement logic will be introduced in a later layer.

contract PositionSettlement is IPositionSettlement {

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to execute settlement.
    address public immutable settlementAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address authority
    ) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        settlementAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Determines whether this implementation supports
    /// a Position.
    /// @param positionId Position identifier.
    /// @return supported True when the Position is valid.
    function supportsSettlement(
        PositionId positionId
    )
        external
        pure
        override
        returns (bool supported)
    {
        return PositionId.unwrap(positionId) != 0;
    }

    //////////////////////////////////////////////////////////////
    // PREVIEW
    //////////////////////////////////////////////////////////////

    /// @notice Previews settlement data.
    /// @param positionId Position identifier.
    /// @param data Settlement-specific data.
    /// @return result Preview result.
    function previewSettlement(
        PositionId positionId,
        bytes calldata data
    )
        external
        pure
        override
        returns (bytes memory result)
    {
        if (PositionId.unwrap(positionId) == 0) {
            revert ZeroValue();
        }

        return data;
    }

    //////////////////////////////////////////////////////////////
    // SETTLE
    //////////////////////////////////////////////////////////////

    /// @notice Executes the base settlement operation.
    /// @dev
    /// This implementation intentionally performs no economic
    /// state transition.
    ///
    /// @param positionId Position identifier.
    /// @param data Settlement-specific data.
    /// @return result Settlement result.
    function settle(
        PositionId positionId,
        bytes calldata data
    )
        external
        override
        returns (bytes memory result)
    {
        if (msg.sender != settlementAuthority) {
            revert Unauthorized();
        }

        if (PositionId.unwrap(positionId) == 0) {
            revert ZeroValue();
        }

        return data;
    }
}
