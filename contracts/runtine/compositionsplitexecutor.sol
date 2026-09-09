// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/CompositionTypes.sol";
import "../kernel/CompositionOperations.sol";
import "../kernel/Errors.sol";
import "./CompositionOperationRegistry.sol";
import "./PositionExecutor.sol";

/// @title PRC-369 Composition Split Executor
/// @author MINTer
/// @notice Executes the Position-level execution boundary for SPLIT
/// composition operations.
/// @dev Dedicated executor for CompositionOperationId.SPLIT.

contract CompositionSplitExecutor {

    //////////////////////////////////////////////////////////////
    // MODULES
    //////////////////////////////////////////////////////////////

    CompositionOperationRegistry public immutable operationRegistry;

    PositionExecutor public immutable positionExecutor;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable splitExecutorAuthority;

    //////////////////////////////////////////////////////////////
    // EXECUTION NONCE
    //////////////////////////////////////////////////////////////

    mapping(CompositionId => uint256) private _executionNonce;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address operationRegistryAddress,
        address positionExecutorAddress,
        address authority
    ) {
        if (operationRegistryAddress == address(0)) {
            revert ZeroAddress();
        }

        if (positionExecutorAddress == address(0)) {
            revert ZeroAddress();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        operationRegistry =
            CompositionOperationRegistry(
                operationRegistryAddress
            );

        positionExecutor =
            PositionExecutor(
                positionExecutorAddress
            );

        splitExecutorAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // EXECUTE SPLIT
    //////////////////////////////////////////////////////////////

    function executeSplit(
        CompositionId compositionId,
        PositionId positionId,
        address account,
        CapabilityMask capability
    )
        external
        returns (uint256 executionId)
    {
        if (msg.sender != splitExecutorAuthority) {
            revert Unauthorized();
        }

        _validateComposition(compositionId);

        _validateSplitOperation(compositionId);

        executionId =
            positionExecutor.execute(
                positionId,
                account,
                capability,
                CompositionOperationId.unwrap(
                    CompositionOperations.SPLIT
                )
            );

        _executionNonce[compositionId] =
            _executionNonce[compositionId] + 1;
    }

    //////////////////////////////////////////////////////////////
    // SUPPORT CHECK
    //////////////////////////////////////////////////////////////

    function supportsSplit(
        CompositionId compositionId
    )
        external
        view
        returns (bool supported)
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            return false;
        }

        if (
            !operationRegistry.isActive(compositionId)
        ) {
            return false;
        }

        return
            operationRegistry.isOperationType(
                compositionId,
                CompositionOperations.SPLIT
            );
    }

    //////////////////////////////////////////////////////////////
    // EXECUTION NONCE
    //////////////////////////////////////////////////////////////

    function executionNonce(
        CompositionId compositionId
    )
        external
        view
        returns (uint256 executionCount)
    {
        return _executionNonce[compositionId];
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateSplitOperation(
        CompositionId compositionId
    )
        internal
        view
    {
        if (
            !operationRegistry.isActive(compositionId)
        ) {
            revert UnsupportedOperation();
        }

        if (
            !operationRegistry.isOperationType(
                compositionId,
                CompositionOperations.SPLIT
            )
        ) {
            revert UnsupportedOperation();
        }
    }

    function _validateComposition(
        CompositionId compositionId
    )
        internal
        pure
    {
        if (
            CompositionId.unwrap(compositionId)
            == bytes32(0)
        ) {
            revert ZeroValue();
        }
    }
}

