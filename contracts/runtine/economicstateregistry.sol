// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/EconomicTypes.sol";
import "../kernel/EconomicState.sol";

/// @title PRC-369 Economic State Registry
/// @author MINTer
/// @notice Registry for Economic States associated with PRC-369 Positions.
/// @dev
/// This Runtime component stores Economic States and associates them
/// with canonical Position identifiers.
///
/// It does NOT:
/// - Define Position identity.
/// - Modify Position lifecycle.
/// - Execute settlement.
/// - Transfer assets.
/// - Define protocol-specific economics.
///
/// PositionRegistry remains authoritative for Position identity
/// and Position runtime.
///
/// EconomicStateRegistry is authoritative only for Economic State data.

contract EconomicStateRegistry {

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    EconomicStateId private _nextStateId;

    mapping(EconomicStateId => EconomicState)
        private _states;

    mapping(PositionId => EconomicStateId)
        private _positionStates;

    mapping(EconomicStateId => bool)
        private _registered;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    address public immutable stateAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address authority
    ) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        stateAuthority = authority;

        _nextStateId =
            EconomicStateId.wrap(1);
    }

    //////////////////////////////////////////////////////////////
    // REGISTER
    //////////////////////////////////////////////////////////////

    function registerEconomicState(
        PositionId positionId,
        EconomicState calldata state
    )
        external
        returns (EconomicStateId stateId)
    {
        _authorize();

        if (
            PositionId.unwrap(positionId) == 0
        ) {
            revert ZeroValue();
        }

        if (
            EconomicStateId.unwrap(
                _positionStates[positionId]
            ) != 0
        ) {
            revert PositionAlreadyRegistered();
        }

        stateId = _nextStateId;

        _nextStateId =
            EconomicStateId.wrap(
                EconomicStateId.unwrap(stateId) + 1
            );

        EconomicState memory storedState = state;

        storedState.stateId = stateId;

        _states[stateId] = storedState;

        _positionStates[positionId] = stateId;

        _registered[stateId] = true;
    }

    //////////////////////////////////////////////////////////////
    // UPDATE
    //////////////////////////////////////////////////////////////

    function updateEconomicState(
        PositionId positionId,
        EconomicState calldata state
    )
        external
    {
        _authorize();

        EconomicStateId stateId =
            _positionStates[positionId];

        if (
            EconomicStateId.unwrap(stateId) == 0
        ) {
            revert PositionNotFound();
        }

        EconomicState memory updatedState = state;

        updatedState.stateId = stateId;

        _states[stateId] = updatedState;
    }

    //////////////////////////////////////////////////////////////
    // EXISTENCE
    //////////////////////////////////////////////////////////////

    function economicStateExists(
        PositionId positionId
    )
        external
        view
        returns (bool exists)
    {
        return
            EconomicStateId.unwrap(
                _positionStates[positionId]
            ) != 0;
    }

    //////////////////////////////////////////////////////////////
    // STATE EXISTENCE
    //////////////////////////////////////////////////////////////

    function stateExists(
        EconomicStateId stateId
    )
        external
        view
        returns (bool registered)
    {
        return _registered[stateId];
    }

    //////////////////////////////////////////////////////////////
    // POSITION STATE ID
    //////////////////////////////////////////////////////////////

    function getPositionStateId(
        PositionId positionId
    )
        external
        view
        returns (EconomicStateId stateId)
    {
        stateId =
            _positionStates[positionId];

        if (
            EconomicStateId.unwrap(stateId) == 0
        ) {
            revert PositionNotFound();
        }
    }

    //////////////////////////////////////////////////////////////
    // GET STATE
    //////////////////////////////////////////////////////////////

    function getEconomicState(
        EconomicStateId stateId
    )
        external
        view
        returns (EconomicState memory state)
    {
        if (!_registered[stateId]) {
            revert PositionNotFound();
        }

        return _states[stateId];
    }

    //////////////////////////////////////////////////////////////
    // RESOLVE POSITION
    //////////////////////////////////////////////////////////////

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
        stateId =
            _positionStates[positionId];

        if (
            EconomicStateId.unwrap(stateId) == 0
        ) {
            revert PositionNotFound();
        }

        state = _states[stateId];
    }

    //////////////////////////////////////////////////////////////
    // NEXT STATE ID
    //////////////////////////////////////////////////////////////

    function nextStateId()
        external
        view
        returns (EconomicStateId stateId)
    {
        return _nextStateId;
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (msg.sender != stateAuthority) {
            revert Unauthorized();
        }
    }
}
