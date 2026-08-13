// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Position Runtime Manager
/// @author MINTer
/// @notice Coordinates controlled Runtime state updates.
/// @dev
/// The Runtime Manager does NOT:
/// - Store a second copy of Position runtime.
/// - Define Position identity.
/// - Define lifecycle semantics.
/// - Manage capabilities.
/// - Execute economic settlement.
///
/// PositionRegistry remains the authoritative Runtime state store.
///
/// This module only coordinates authorized Runtime updates.

contract PositionRuntimeManager {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Position Registry.
    PositionRegistry public immutable registry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to update Runtime state.
    address public immutable runtimeManagerAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Runtime Manager.
    /// @param registryAddress Position Registry address.
    /// @param authority Runtime Manager authority.
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
            PositionRegistry(registryAddress);

        runtimeManagerAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // UPDATE RUNTIME
    //////////////////////////////////////////////////////////////

    /// @notice Updates the Runtime state of a Position.
    /// @dev
    /// The Registry remains the actual storage layer.
    ///
    /// @param positionId Position identifier.
    /// @param runtime New Runtime state.
    function updateRuntime(
        PositionId positionId,
        PositionRuntime calldata runtime
    )
        external
    {
        _authorize();

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        registry.updateRuntime(
            positionId,
            runtime
        );
    }

    //////////////////////////////////////////////////////////////
    // UPDATE STATE
    //////////////////////////////////////////////////////////////

    /// @notice Updates only the lifecycle state of a Position.
    /// @param positionId Position identifier.
    /// @param newState New Position state.
    function updateState(
        PositionId positionId,
        PositionStateId newState
    )
        external
    {
        _authorize();

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        PositionRuntime memory runtime =
            registry.getPositionRuntime(
                positionId
            );

        runtime.stateId = newState;

        runtime.nonce = PositionNonce.wrap(
            PositionNonce.unwrap(runtime.nonce) + 1
        );

        registry.updateRuntime(
            positionId,
            runtime
        );
    }

    //////////////////////////////////////////////////////////////
    // READ RUNTIME
    //////////////////////////////////////////////////////////////

    /// @notice Returns the current Runtime state.
    /// @param positionId Position identifier.
    /// @return runtime Current Runtime state.
    function getRuntime(
        PositionId positionId
    )
        external
        view
        returns (
            PositionRuntime memory runtime
        )
    {
        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        return registry.getPositionRuntime(
            positionId
        );
    }

    //////////////////////////////////////////////////////////////
    // READ STATE
    //////////////////////////////////////////////////////////////

    /// @notice Returns the current lifecycle state.
    /// @param positionId Position identifier.
    /// @return state Current Position state.
    function getState(
        PositionId positionId
    )
        external
        view
        returns (
            PositionStateId state
        )
    {
        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        PositionRuntime memory runtime =
            registry.getPositionRuntime(
                positionId
            );

        return runtime.stateId;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Runtime Manager authority.
    function _authorize()
        internal
        view
    {
        if (
            msg.sender !=
            runtimeManagerAuthority
        ) {
            revert Unauthorized();
        }
    }
}
