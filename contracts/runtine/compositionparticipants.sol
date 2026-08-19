// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionTypes.sol";

/// @title PRC-369 Composition Participants
/// @author MINTer
/// @notice Stores the Position participants associated with a composition.
/// @dev
/// This contract records source and target Positions for a composition.
///
/// It does NOT:
/// - Modify Position state.
/// - Modify EconomicState.
/// - Transfer assets.
/// - Calculate economic values.
/// - Execute split or merge.
/// - Create or destroy Positions.
///
/// It is a structural runtime component only.

contract CompositionParticipants {

    //////////////////////////////////////////////////////////////
    // PARTICIPANT TYPES
    //////////////////////////////////////////////////////////////

    /// @notice Participant role within a composition.
    uint8 internal constant SOURCE = 1;
    uint8 internal constant TARGET = 2;

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Source Positions associated with a composition.
    mapping(CompositionId => PositionId[]) private _sources;

    /// @notice Target Positions associated with a composition.
    mapping(CompositionId => PositionId[]) private _targets;

    /// @notice Prevents duplicate source registration.
    mapping(CompositionId => mapping(PositionId => bool))
        private _sourceRegistered;

    /// @notice Prevents duplicate target registration.
    mapping(CompositionId => mapping(PositionId => bool))
        private _targetRegistered;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage participants.
    address public immutable participantAuthority;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    constructor(
        address authority
    ) {
        if (authority == address(0)) {
            revert ZeroAddress();
        }

        participantAuthority = authority;
    }

    //////////////////////////////////////////////////////////////
    // ADD SOURCE
    //////////////////////////////////////////////////////////////

    /// @notice Adds a source Position to a composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Source Position identifier.
    function addSource(
        CompositionId compositionId,
        PositionId positionId
    )
        external
    {
        _authorize();

        _validateIdentifiers(
            compositionId,
            positionId
        );

        if (
            _sourceRegistered[
                compositionId
            ][positionId]
        ) {
            revert PositionAlreadyRegistered();
        }

        _sources[compositionId].push(positionId);

        _sourceRegistered[
            compositionId
        ][positionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // ADD TARGET
    //////////////////////////////////////////////////////////////

    /// @notice Adds a target Position to a composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Target Position identifier.
    function addTarget(
        CompositionId compositionId,
        PositionId positionId
    )
        external
    {
        _authorize();

        _validateIdentifiers(
            compositionId,
            positionId
        );

        if (
            _targetRegistered[
                compositionId
            ][positionId]
        ) {
            revert PositionAlreadyRegistered();
        }

        _targets[compositionId].push(positionId);

        _targetRegistered[
            compositionId
        ][positionId] = true;
    }

    //////////////////////////////////////////////////////////////
    // SOURCE COUNT
    //////////////////////////////////////////////////////////////

    /// @notice Returns the number of source Positions.
    /// @param compositionId Composition identifier.
    function sourceCount(
        CompositionId compositionId
    )
        external
        view
        returns (uint256)
    {
        return _sources[compositionId].length;
    }

    //////////////////////////////////////////////////////////////
    // TARGET COUNT
    //////////////////////////////////////////////////////////////

    /// @notice Returns the number of target Positions.
    /// @param compositionId Composition identifier.
    function targetCount(
        CompositionId compositionId
    )
        external
        view
        returns (uint256)
    {
        return _targets[compositionId].length;
    }

    //////////////////////////////////////////////////////////////
    // SOURCE POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Returns a source Position by index.
    /// @param compositionId Composition identifier.
    /// @param index Source index.
    function getSource(
        CompositionId compositionId,
        uint256 index
    )
        external
        view
        returns (PositionId positionId)
    {
        if (
            index >= _sources[compositionId].length
        ) {
            revert PositionNotFound();
        }

        return _sources[compositionId][index];
    }

    //////////////////////////////////////////////////////////////
    // TARGET POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Returns a target Position by index.
    /// @param compositionId Composition identifier.
    /// @param index Target index.
    function getTarget(
        CompositionId compositionId,
        uint256 index
    )
        external
        view
        returns (PositionId positionId)
    {
        if (
            index >= _targets[compositionId].length
        ) {
            revert PositionNotFound();
        }

        return _targets[compositionId][index];
    }

    //////////////////////////////////////////////////////////////
    // SOURCE CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position is a source.
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    function isSource(
        CompositionId compositionId,
        PositionId positionId
    )
        external
        view
        returns (bool)
    {
        return
            _sourceRegistered[
                compositionId
            ][positionId];
    }

    //////////////////////////////////////////////////////////////
    // TARGET CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position is a target.
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    function isTarget(
        CompositionId compositionId,
        PositionId positionId
    )
        external
        view
        returns (bool)
    {
        return
            _targetRegistered[
                compositionId
            ][positionId];
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL VALIDATION
    //////////////////////////////////////////////////////////////

    function _validateIdentifiers(
        CompositionId compositionId,
        PositionId positionId
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

        if (
            PositionId.unwrap(positionId)
            == 0
        ) {
            revert ZeroValue();
        }
    }

    //////////////////////////////////////////////////////////////
    // AUTHORIZATION
    //////////////////////////////////////////////////////////////

    function _authorize()
        internal
        view
    {
        if (
            msg.sender != participantAuthority
        ) {
            revert Unauthorized();
        }
    }
}
