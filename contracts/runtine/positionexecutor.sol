// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CapabilityFlags.sol";
import "./PositionRegistry.sol";
import "./PositionOperations.sol";
import "./PositionAuthorization.sol";

/// @title PRC-369 Position Executor
/// @author MINTer
/// @notice Executes authorized Runtime operations on PRC-369 Positions.
/// @dev
/// Runtime execution boundary.
///
/// The Executor does NOT:
/// - Define Position identity.
/// - Store Position runtime.
/// - Modify lifecycle state directly.
/// - Modify capabilities.
/// - Define authorization rules.
/// - Execute economic settlement.
///
/// Validation and authorization are delegated to the corresponding
/// Runtime modules.
contract PositionExecutor {

    //////////////////////////////////////////////////////////////
    // MODULES
    //////////////////////////////////////////////////////////////

    PositionRegistry public immutable registry;

    PositionOperations public immutable operations;

    PositionAuthorization public immutable authorization;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable executorAuthority;

    //////////////////////////////////////////////////////////////
    // EXECUTION NONCE
    //////////////////////////////////////////////////////////////

    mapping(PositionId => uint256) private _executionNonce;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address registryAddress,
        address operationsAddress,
        address authorizationAddress,
        address authority
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (operationsAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authorizationAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registry =
            PositionRegistry(registryAddress);

        operations =
            PositionOperations(operationsAddress);

        authorization =
            PositionAuthorization(authorizationAddress);

        executorAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // EXECUTE
    //////////////////////////////////////////////////////////////

    function execute(
        PositionId positionId,
        address account,
        CapabilityMask capability,
        bytes32 operation
    )
        external
        returns (uint256 executionId)
    {
        if (msg.sender != executorAuthority) {
            revert Unauthorized();
        }

        if (account == address(0)) {
            revert ZeroAddress();
        }

        if (operation == bytes32(0)) {
            revert ZeroValue();
        }

        if (!registry.positionExists(positionId)) {
            revert PositionNotFound();
        }

        bool authorized =
            authorization.canExecute(
                positionId,
                account,
                capability,
                operation
            );

        if (!authorized) {
            revert Unauthorized();
        }

        bool supported =
            operations.supportsOperation(
                positionId,
                capability
            );

        if (!supported) {
            revert UnsupportedOperation();
        }

        executionId =
            _executionNonce[positionId] + 1;

        _executionNonce[positionId] =
            executionId;
    }

    //////////////////////////////////////////////////////////////
    // EXECUTION STATUS
    //////////////////////////////////////////////////////////////

    function executionNonce(
        PositionId positionId
    )
        external
        view
        returns (uint256 executionId)
    {
        return _executionNonce[positionId];
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION CHECK
    //////////////////////////////////////////////////////////////

    function canExecute(
        PositionId positionId,
        address account,
        CapabilityMask capability,
        bytes32 operation
    )
        external
        view
        returns (bool allowed)
    {
        if (account == address(0)) {
            return false;
        }

        if (operation == bytes32(0)) {
            return false;
        }

        if (!registry.positionExists(positionId)) {
            return false;
        }

        return authorization.canExecute(
            positionId,
            account,
            capability,
            operation
        );
    }
}
