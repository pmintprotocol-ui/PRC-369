// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/EconomicTypes.sol";
import "../kernel/EconomicState.sol";
import "./EconomicStateRegistry.sol";
import "../adapters/SettlementController.sol";

/// @title PRC-369 Economic Settlement Controller
/// @author MINTer
/// @notice Coordinates Economic States with Settlement operations.
/// @dev
/// This component acts as the bridge between Economic State
/// and the Settlement layer.
///
/// It does NOT:
/// - Modify Position lifecycle.
/// - Modify Economic State storage.
/// - Define economic valuation.
/// - Execute asset transfers.
/// - Define protocol-specific settlement rules.
///
/// EconomicStateRegistry remains authoritative for Economic State.
/// SettlementController remains authoritative for Settlement execution.

contract EconomicSettlementController {

    //////////////////////////////////////////////////////////////
    // REGISTRIES / CONTROLLERS
    //////////////////////////////////////////////////////////////

    /// @notice Economic State Registry.
    EconomicStateRegistry public immutable stateRegistry;

    /// @notice Settlement Controller.
    SettlementController public immutable settlementController;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to execute Economic Settlement.
    address public immutable settlementAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address stateRegistryAddress,
        address settlementControllerAddress,
        address authority
    ) {
        if (stateRegistryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (settlementControllerAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        stateRegistry =
            EconomicStateRegistry(
                stateRegistryAddress
            );

        settlementController =
            SettlementController(
                settlementControllerAddress
            );

        settlementAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE ECONOMIC STATE
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the Economic State associated with a Position.
    /// @param positionId Position identifier.
    /// @return stateId Economic State identifier.
    /// @return state Economic State data.
    function resolveEconomicState(
        PositionId positionId
    )
        external
        view
        returns (
            EconomicStateId stateId,
            EconomicState memory state
        )
    {
        return stateRegistry.resolveEconomicState(
            positionId
        );
    }

    //////////////////////////////////////////////////////////////
    // SETTLEMENT SUPPORT
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether an Economic State can be settled
    /// through a specific Settlement operation.
    /// @param positionId Position identifier.
    /// @param operation Settlement operation identifier.
    /// @return supported True if supported.
    function supportsEconomicSettlement(
        PositionId positionId,
        bytes32 operation
    )
        external
        view
        returns (bool supported)
    {
        if (
            !stateRegistry.economicStateExists(
                positionId
            )
        ) {
            return false;
        }

        return
            settlementController.supportsSettlement(
                positionId,
                operation
            );
    }

    //////////////////////////////////////////////////////////////
    // PREVIEW
    //////////////////////////////////////////////////////////////

    /// @notice Previews settlement for the Economic State
    /// associated with a Position.
    /// @param positionId Position identifier.
    /// @param operation Settlement operation identifier.
    /// @param data Settlement-specific parameters.
    /// @return stateId Economic State identifier.
    /// @return result Settlement preview result.
    function previewEconomicSettlement(
        PositionId positionId,
        bytes32 operation,
        bytes calldata data
    )
        external
        view
        returns (
            EconomicStateId stateId,
            bytes memory result
        )
    {
        EconomicState memory state;

        (
            stateId,
            state
        ) = stateRegistry.resolveEconomicState(
            positionId
        );

        if (
            !settlementController.supportsSettlement(
                positionId,
                operation
            )
        ) {
            revert UnsupportedOperation();
        }

        bytes memory settlementData =
            abi.encode(
                state,
                data
            );

        result =
            settlementController.previewSettlement(
                positionId,
                operation,
                settlementData
            );
    }

    //////////////////////////////////////////////////////////////
    // EXECUTE
    //////////////////////////////////////////////////////////////

    /// @notice Executes settlement for the Economic State
    /// associated with a Position.
    /// @param positionId Position identifier.
    /// @param operation Settlement operation identifier.
    /// @param data Settlement-specific parameters.
    /// @return stateId Economic State identifier.
    /// @return result Settlement result.
    function settleEconomicState(
        PositionId positionId,
        bytes32 operation,
        bytes calldata data
    )
        external
        returns (
            EconomicStateId stateId,
            bytes memory result
        )
    {
        _authorize();

        EconomicState memory state;

        (
            stateId,
            state
        ) = stateRegistry.resolveEconomicState(
            positionId
        );

        if (
            !settlementController.supportsSettlement(
                positionId,
                operation
            )
        ) {
            revert UnsupportedOperation();
        }

        bytes memory settlementData =
            abi.encode(
                state,
                data
            );

        result =
            settlementController.settle(
                positionId,
                operation,
                settlementData
            );
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates Economic Settlement authority.
    function _authorize()
        internal
        view
    {
        if (
            msg.sender != settlementAuthority
        ) {
            revert Unauthorized();
        }
    }
}
