// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/Events.sol";
import "../kernel/PositionIdentity.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";

contract PositionRegistry {

    PositionId private _nextPositionId;

    mapping(PositionId => PositionDefinition) private _definitions;
    mapping(PositionId => PositionRuntime) private _runtime;
    mapping(PositionId => bool) private _registered;

    address public immutable registryAuthority;
    address public runtimeAuthority;

    constructor(address authority) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registryAuthority = authority;
        _nextPositionId = PositionId.wrap(1);
    }

    function setRuntimeAuthority(address authority) external {
        if (msg.sender != registryAuthority) {
            revert Unauthorized();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        runtimeAuthority = authority;
    }

    function registerPosition(
        PositionDefinition calldata definition
    )
        external
        returns (PositionId positionId)
    {
        if (msg.sender != registryAuthority) {
            revert Unauthorized();
        }

        if (
            ProtocolId.unwrap(
                definition.descriptor.protocol
            ) == bytes32(0)
        ) {
            revert InvalidProtocol();
        }

        if (
            PositionClassId.unwrap(
                definition.descriptor.classId
            ) == 0
        ) {
            revert InvalidPositionClass();
        }

        if (
            PositionFamilyId.unwrap(
                definition.descriptor.familyId
            ) == 0
        ) {
            revert InvalidPositionFamily();
        }

        positionId = _nextPositionId;

        uint256 nextId = PositionId.unwrap(positionId) + 1;

        _nextPositionId = PositionId.wrap(nextId);

        _definitions[positionId] = definition;

        _runtime[positionId] = PositionRuntime({
            stateId: PositionStates.CREATED,
            generation: Generation.wrap(0),
            nonce: PositionNonce.wrap(0),
            version: VersionId.wrap(0)
        });

        _registered[positionId] = true;

        emit PositionRegistered(positionId);
    }

    function updateRuntime(
        PositionId positionId,
        PositionRuntime calldata runtime
    )
        external
    {
        if (msg.sender != runtimeAuthority) {
            revert Unauthorized();
        }

        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        _runtime[positionId] = runtime;
    }

    function updateCapabilities(
        PositionId positionId,
        CapabilityMask capabilities
    )
        external
    {
        if (msg.sender != runtimeAuthority) {
            revert Unauthorized();
        }

        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        _definitions[positionId].capabilities = capabilities;
    }

    function positionExists(
        PositionId positionId
    )
        external
        view
        returns (bool)
    {
        return _registered[positionId];
    }

    function getPositionDefinition(
        PositionId positionId
    )
        external
        view
        returns (PositionDefinition memory)
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        return _definitions[positionId];
    }

    function getPositionRuntime(
        PositionId positionId
    )
        external
        view
        returns (PositionRuntime memory)
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        return _runtime[positionId];
    }

    function resolvePosition(
        PositionId positionId
    )
        external
        view
        returns (
            PositionDefinition memory definition,
            PositionRuntime memory runtime
        )
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        definition = _definitions[positionId];
        runtime = _runtime[positionId];
    }

    function nextPositionId()
        external
        view
        returns (PositionId)
    {
        return _nextPositionId;
    }
}
