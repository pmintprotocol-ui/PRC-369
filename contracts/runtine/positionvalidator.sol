// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/PositionIdentity.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";
import "./PositionRegistry.sol";

/// @title PRC-369 Position Validator
/// @author MINTer
/// @notice Validates the canonical structural invariants of PRC-369 Positions.
/// @dev
/// Runtime component responsible for validating Position identity and
/// runtime state before higher-level Runtime operations are executed.
///
/// PositionValidator does NOT:
/// - Store Position identity.
/// - Modify Position runtime.
/// - Execute lifecycle transitions.
/// - Modify capabilities.
/// - Manage authorization.
///
/// It only performs deterministic validation against the Kernel model.

contract PositionValidator {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Position Registry used as the authoritative Position source.
    PositionRegistry public immutable registry;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Position Validator.
    /// @param registryAddress Position Registry address.
    constructor(
        address registryAddress
    ) {
        if (registryAddress == address(0)) {
            revert ZeroAddress();
        }

        registry = PositionRegistry(registryAddress);
    }

    //////////////////////////////////////////////////////////////
    // POSITION VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates that a Position exists and has a valid identity.
    /// @param positionId Position identifier.
    /// @return valid True when the Position identity is valid.
    function validatePosition(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (!registry.positionExists(positionId)) {
            return false;
        }

        PositionIdentity memory identity =
            registry.getPositionIdentity(positionId);

        if (
            ProtocolId.unwrap(
                identity.descriptor.protocol
            ) == bytes32(0)
        ) {
            return false;
        }

        if (
            PositionClassId.unwrap(
                identity.descriptor.classId
            ) == 0
        ) {
            return false;
        }

        if (
            PositionFamilyId.unwrap(
                identity.descriptor.familyId
            ) == 0
        ) {
            return false;
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // RUNTIME VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates that a Position has a recognized runtime state.
    /// @param positionId Position identifier.
    /// @return valid True when the runtime state is valid.
    function validateRuntime(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (!registry.positionExists(positionId)) {
            return false;
        }

        PositionRuntime memory runtime =
            registry.getPositionRuntime(positionId);

        uint256 state =
            PositionStateId.unwrap(runtime.stateId);

        if (state == 0) {
            return false;
        }

        if (state > PositionStateId.unwrap(PositionStates.ARCHIVED)) {
            return false;
        }

        return true;
    }

    //////////////////////////////////////////////////////////////
    // COMPLETE VALIDATION
    //////////////////////////////////////////////////////////////

    /// @notice Validates both Position identity and runtime state.
    /// @param positionId Position identifier.
    /// @return valid True when the complete Position is valid.
    function validate(
        PositionId positionId
    )
        external
        view
        returns (bool valid)
    {
        if (!registry.positionExists(positionId)) {
            return false;
        }

        PositionIdentity memory identity =
            registry.getPositionIdentity(positionId);

        PositionRuntime memory runtime =
            registry.getPositionRuntime(positionId);

        if (
            ProtocolId.unwrap(
                identity.descriptor.protocol
            ) == bytes32(0)
        ) {
            return false;
        }

        if (
            PositionClassId.unwrap(
                identity.descriptor.classId
            ) == 0
        ) {
            return false;
        }

        if (
            PositionFamilyId.unwrap(
                identity.descriptor.familyId
            ) == 0
        ) {
            return false;
        }

        uint256 state =
            PositionStateId.unwrap(runtime.stateId);

        if (state == 0) {
            return false;
        }

        if (
            state >
            PositionStateId.unwrap(PositionStates.ARCHIVED)
        ) {
            return false;
        }

        return true;
    }
}
