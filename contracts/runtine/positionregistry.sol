// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/Events.sol";
import "../kernel/PositionIdentity.sol";
import "../kernel/PositionRuntime.sol";
import "../kernel/PositionStates.sol";

/// @title PRC-369 Position Registry
/// @author MINTer
/// @notice Canonical registry for PRC-369 Positions.
/// @dev
/// Foundational registry component of the PRC-369 Runtime.
///
/// Responsibilities:
/// - Register Positions.
/// - Assign unique PositionIds.
/// - Store Position identity.
/// - Initialize Position runtime state.
/// - Resolve registered Positions.
///
/// The Registry does NOT:
/// - Execute lifecycle transitions.
/// - Execute settlements.
/// - Modify economic rights.
/// - Interact with Asset Adapters.
/// - Contain protocol-specific business logic.
///
/// Those responsibilities belong to dedicated Runtime modules.
contract PositionRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Next Position identifier to be assigned.
    PositionId private _nextPositionId;

    /// @notice Identity associated with each Position.
    mapping(PositionId => PositionDefinition)
        private _definitions;

    /// @notice Runtime state associated with each Position.
    mapping(PositionId => PositionRuntime)
        private _runtime;

    /// @notice Tracks whether a Position has been registered.
    mapping(PositionId => bool)
        private _registered;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Address authorized to register Positions.
    address public immutable registryAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Position Registry.
    /// @param authority Address authorized to register Positions.
    constructor(address authority) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        registryAuthority = authority;
        _nextPositionId = PositionId.wrap(1);
    }

    //////////////////////////////////////////////////////////////
    // POSITION REGISTRATION
    //////////////////////////////////////////////////////////////

    /// @notice Registers a new PRC-369 Position.
    /// @param definition Immutable Position definition.
    /// @return positionId Newly assigned Position identifier.
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
            definition.descriptor.protocol
                == ProtocolId.wrap(bytes32(0))
        ) {
            revert InvalidProtocol();
        }

        if (
            definition.descriptor.classId
                == PositionClassId.wrap(0)
        ) {
            revert InvalidPositionClass();
        }

        if (
            definition.descriptor.familyId
                == PositionFamilyId.wrap(0)
        ) {
            revert InvalidPositionFamily();
        }

        positionId = _nextPositionId;

        uint256 nextId =
            PositionId.unwrap(positionId) + 1;

        if (nextId == 0) {
            revert KernelInvariantViolation();
        }

        _nextPositionId =
            PositionId.wrap(nextId);

        _definitions[positionId] = definition;

        _runtime[positionId] = PositionRuntime({
            stateId: PositionStates.CREATED,
            generation: Generation.wrap(0),
            nonce: PositionNonce.wrap(0)
        });

        _registered[positionId] = true;

        emit PositionRegistered(positionId);
    }

    //////////////////////////////////////////////////////////////
    // EXISTENCE
    //////////////////////////////////////////////////////////////

    /// @notice Determines whether a Position is registered.
    /// @param positionId Position identifier.
    /// @return True if the Position exists.
    function positionExists(
        PositionId positionId
    )
        public
        view
        returns (bool)
    {
        return _registered[positionId];
    }

    //////////////////////////////////////////////////////////////
    // POSITION DEFINITION
    //////////////////////////////////////////////////////////////

    /// @notice Returns the complete definition of a Position.
    /// @param positionId Position identifier.
    /// @return definition Position definition.
    function getPositionDefinition(
        PositionId positionId
    )
        external
        view
        returns (
            PositionDefinition memory definition
        )
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        return _definitions[positionId];
    }

    //////////////////////////////////////////////////////////////
    // POSITION RUNTIME
    //////////////////////////////////////////////////////////////

    /// @notice Returns the current runtime state of a Position.
    /// @param positionId Position identifier.
    /// @return runtime Current runtime state.
    function getPositionRuntime(
        PositionId positionId
    )
        external
        view
        returns (
            PositionRuntime memory runtime
        )
    {
        if (!_registered[positionId]) {
            revert PositionNotFound();
        }

        return _runtime[positionId];
    }

    //////////////////////////////////////////////////////////////
    // POSITION RESOLUTION
    //////////////////////////////////////////////////////////////

    /// @notice Resolves the definition and runtime state of a Position.
    /// @param positionId Position identifier.
    /// @return definition Position definition.
    /// @return runtime Current runtime state.
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

    //////////////////////////////////////////////////////////////
    // NEXT POSITION ID
    //////////////////////////////////////////////////////////////

    /// @notice Returns the next PositionId that will be assigned.
    /// @return positionId Next available Position identifier.
    function nextPositionId()
        external
        view
        returns (PositionId positionId)
    {
        return _nextPositionId;
    }
}
