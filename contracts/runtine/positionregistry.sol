// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/Events.sol";
import "../kernel/PositionIdentity.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";

contract PositionRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    PositionId private _nextPositionId;

    mapping(PositionId => PositionIdentity) private _identities;

    mapping(PositionId => PositionRuntime) private _runtime;

    mapping(PositionId => bool) private _registered;

    //////////////////////////////////////////////////////////////
    // AUTHORITIES
    //////////////////////////////////////////////////////////////

    address public immutable registryAuthority;

    address public runtimeAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(address authority) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registryAuthority = authority;

        _nextPositionId = PositionId.wrap(1);
    }

    //////////////////////////////////////////////////////////////
    // RUNTIME AUTHORITY
    //////////////////////////////////////////////////////////////

    function setRuntimeAuthority(
        address authority
    )
        external
    {
        if (msg.sender != registryAuthority) {
            revert Unauthorized();
        }

        if (authority == address(0)) {
            revert ZeroAddress();
        }

        runtimeAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // POSITION REGISTRATION
    //////////////////////////////////////////////////////////////

    function registerPosition(
        PositionIdentity calldata identity
    )
        external
        returns (PositionId positionId)
    {
        if (msg.sender != registryAuthority) {
            revert Unauthorized();
        }

        if (
            ProtocolId.unwrap(
                identity.descriptor.protocol
            ) == bytes32(0)
        ) {
            revert InvalidProtocol();
        }

        if (
            PositionClassId.unwrap(
                identity.descriptor.classId
            ) == 0
        ) {
            revert InvalidPositionClass();
        }

        if (
            PositionFamilyId.unwrap(
                identity.descriptor.familyId
            ) == 0
        ) {
            revert InvalidPositionFamily();
        }

        //////////////////////////////////////////////////////////
        // ASSIGN POSITION ID
        //////////////////////////////////////////////////////////

        positionId = _nextPositionId;

        _nextPositionId = PositionId.wrap(
            PositionId.unwrap(positionId) + 1
        );

        //////////////////////////////////////////////////////////
        // STORE IDENTITY
        //////////////////////////////////////////////////////////

        _identities[positionId] = identity;

        //////////////////////////////////////////////////////////
        // INITIAL RUNTIME
        //////////////////////////////////////////////////////////

        _runtime[positionId] = PositionRuntime({
            stateId: PositionStates.CREATED,
            generation: Generation.wrap(0),
            nonce: PositionNonce.wrap(0),
            version: VersionId.wrap(0)
        });

        //////////////////////////////////////////////////////////
        // REGISTER
        //////////////////////////////////////////////////////////

        _registered[positionId] = true;

        emit PositionRegistered(positionId);
    }

    //////////////////////////////////////////////////////////////
    // RUNTIME UPDATE
    //////////////////////////////////////////////////////////////

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

    //////////////////////////////////////////////////////////////
    // EXISTENCE
    //////////////////////////////////////////////////////////////

    function positionExists(
        PositionId positionId
    )
        external
        view
        returns (bool)
    {
        return _registered[positionId];
    }

    //////////////////////////////////////////////////////////////
    // IDENTITY
    //////////////////////////////////////////////////////////////

    function getPositionIdentity(
        PositionId positionId
    )
        external
        view
        returns (PositionIdentity memory)
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        return _identities[positionId];
    }

    //////////////////////////////////////////////////////////////
    // RUNTIME
    //////////////////////////////////////////////////////////////

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

    //////////////////////////////////////////////////////////////
    // RESOLUTION
    //////////////////////////////////////////////////////////////

    function resolvePosition(
        PositionId positionId
    )
        external
        view
        returns (
            PositionIdentity memory identity,
            PositionRuntime memory runtime
        )
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        identity = _identities[positionId];
        runtime = _runtime[positionId];
    }

    //////////////////////////////////////////////////////////////
    // NEXT ID
    //////////////////////////////////////////////////////////////

    function nextPositionId()
        external
        view
        returns (PositionId)
    {
        return _nextPositionId;
    }
}
