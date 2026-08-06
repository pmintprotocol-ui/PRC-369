// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Kernel Errors
/// @author MINTer
/// @notice Defines all custom errors used by the PRC-369 Kernel.
/// @dev
/// Every protocol module MUST use these errors whenever applicable.
/// New modules should extend this library rather than creating duplicate errors.
library Errors {

    /*//////////////////////////////////////////////////////////////
                            GENERAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Caller is not authorized.
    error Unauthorized();

    /// @notice Invalid address.
    error InvalidAddress();

    /// @notice Invalid identifier.
    error InvalidId();

    /// @notice Invalid amount.
    error InvalidAmount();

    /// @notice Invalid configuration.
    error InvalidConfiguration();

    /*//////////////////////////////////////////////////////////////
                           POSITION
    //////////////////////////////////////////////////////////////*/

    /// @notice Position does not exist.
    error PositionNotFound();

    /// @notice Position already exists.
    error PositionAlreadyExists();

    /// @notice Position is locked.
    error PositionLocked();

    /// @notice Position is inactive.
    error PositionInactive();

    /// @notice Invalid position state.
    error InvalidPositionState();

    /*//////////////////////////////////////////////////////////////
                           RESERVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reserve not found.
    error ReserveNotFound();

    /// @notice Reserve already registered.
    error ReserveAlreadyRegistered();

    /// @notice Reserve ownership verification failed.
    error InvalidReserveOwner();

    /// @notice Unsupported reserve type.
    error UnsupportedReserveType();

    /*//////////////////////////////////////////////////////////////
                         ASSET ADAPTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Asset Adapter not registered.
    error AdapterNotFound();

    /// @notice Asset Adapter already registered.
    error AdapterAlreadyRegistered();

    /// @notice Adapter is incompatible.
    error AdapterNotCompatible();

    /*//////////////////////////////////////////////////////////////
                            RIGHTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Rights cannot be transferred.
    error RightsNotTransferable();

    /// @notice Rights already claimed.
    error RightsAlreadyClaimed();

    /// @notice Nothing available to claim.
    error NothingToClaim();

    /*//////////////////////////////////////////////////////////////
                           SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Settlement validation failed.
    error SettlementFailed();

    /// @notice Economic conservation check failed.
    error EconomicConservationViolation();

    /*//////////////////////////////////////////////////////////////
                             VAULT
    //////////////////////////////////////////////////////////////*/

    /// @notice Vault already contains this reserve.
    error AlreadyDeposited();

    /// @notice Vault does not contain requested reserve.
    error NotDeposited();

    /// @notice Vault operation failed.
    error VaultOperationFailed();
}
