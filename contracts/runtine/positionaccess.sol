// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Position Access
/// @author MINTer
/// @notice Controls runtime authorization for PRC-369 Positions.
/// @dev
/// Runtime component responsible for assigning and revoking
/// operational access to specific Position identifiers.
///
/// PositionAccess does not define Position identity.
/// PositionAccess does not control lifecycle states.
/// PositionAccess does not modify capabilities.
///
/// It only manages runtime access permissions.

contract PositionAccess {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Position Registry used to verify Position existence.
    PositionRegistry public immutable registry;

    /// @notice Authority allowed to manage Position access.
    address public immutable accessAuthority;

    /// @notice Position-specific authorization mapping.
    mapping(PositionId => mapping(address => bool))
        private _authorized;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Position Access controller.
    /// @param registryAddress Position Registry address.
    /// @param authority Authority allowed to manage access.
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

        registry = PositionRegistry(registryAddress);
        accessAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZE
    //////////////////////////////////////////////////////////////

    /// @notice Grants runtime access to an account for a Position.
    /// @param positionId Position identifier.
    /// @param account Account receiving access.
    function authorize(
        PositionId positionId,
        address account
    )
        external
    {
        _authorize();

        if (account == address(0)) {
            revert ZeroAddress();
        }

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        _authorized[positionId][account] = true;
    }

    //////////////////////////////////////////////////////////////
    // REVOKE
    //////////////////////////////////////////////////////////////

    /// @notice Revokes runtime access from an account.
    /// @param positionId Position identifier.
    /// @param account Account losing access.
    function revoke(
        PositionId positionId,
        address account
    )
        external
    {
        _authorize();

        if (account == address(0)) {
            revert ZeroAddress();
        }

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        _authorized[positionId][account] = false;
    }

    //////////////////////////////////////////////////////////////
    // ACCESS CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an account has runtime access.
    /// @param positionId Position identifier.
    /// @param account Account being checked.
    /// @return True when access is granted.
    function isAuthorized(
        PositionId positionId,
        address account
    )
        external
        view
        returns (bool)
    {
        return _authorized[positionId][account];
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates administrative access.
    function _authorize()
        internal
        view
    {
        if (msg.sender != accessAuthority) {
            revert Unauthorized();
        }
    }
}
