// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionTypes.sol";

import "./PositionRegistry.sol";

/// @title PRC-369 Composition Position Registry
/// @author MINTer
/// @notice Registers the Positions participating in a PRC-369 Composition.
/// @dev
/// This Runtime component is responsible ONLY for the relationship:
///
///      CompositionId <-> PositionId
///
/// It records which Positions participate in a concrete Composition.
///
/// This contract does NOT:
/// - Define Position identity.
/// - Define Composition identity.
/// - Manage Position lifecycle state.
/// - Manage Composition lifecycle state.
/// - Modify Position capabilities.
/// - Execute SPLIT.
/// - Execute MERGE.
/// - Execute COMPOSE.
/// - Transfer assets.
/// - Modify EconomicState.
/// - Calculate economic values.
/// - Perform settlement.
/// - Create economic value.
/// - Destroy economic value.
///
/// Execution and economic semantics belong to later Runtime layers.

contract CompositionPositionRegistry {

    //////////////////////////////////////////////////////////////
    // REGISTRIES
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Position Registry.
    PositionRegistry public immutable positionRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage Composition participants.
    address public immutable positionAuthority;

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Positions registered for each Composition.
    mapping(CompositionId => PositionId[])
        private _positions;

    /// @notice Prevents the same Position from being registered
    ///         more than once in the same Composition.
    mapping(
        CompositionId =>
            mapping(PositionId => bool)
    )
        private _registered;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition Position Registry.
    /// @param registryAddress Authoritative Position Registry.
    /// @param authority Authority allowed to manage participants.
    constructor(
        address registryAddress,
        address authority
    ) {
        if (
            registryAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            authority == address(0)
        ) {
            revert ZeroAddress();
        }

        positionRegistry =
            PositionRegistry(
                registryAddress
            );

        positionAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Registers a Position as a participant of a Composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    function registerPosition(
        CompositionId compositionId,
        PositionId positionId
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        _validatePositionId(
            positionId
        );

        if (
            !positionRegistry.positionExists(
                positionId
            )
        ) {
            revert PositionNotFound();
        }

        if (
            _registered[
                compositionId
            ][
                positionId
            ]
        ) {
            revert PositionAlreadyRegistered();
        }

        _positions[
            compositionId
        ].push(
            positionId
        );

        _registered[
            compositionId
        ][
            positionId
        ] = true;
    }

    //////////////////////////////////////////////////////////////
    // REMOVE POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Removes a Position from a Composition.
    /// @dev
    /// Removal only changes the Composition-to-Position registry.
    /// It does not modify the Position itself.
    ///
    /// Array order is preserved by shifting subsequent entries.
    ///
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    function removePosition(
        CompositionId compositionId,
        PositionId positionId
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        _validatePositionId(
            positionId
        );

        if (
            !_registered[
                compositionId
            ][
                positionId
            ]
        ) {
            revert PositionNotFound();
        }

        PositionId[] storage positions =
            _positions[
                compositionId
            ];

        uint256 length =
            positions.length;

        for (
            uint256 i = 0;
            i < length;
            i++
        ) {
            if (
                PositionId.unwrap(
                    positions[i]
                )
                ==
                PositionId.unwrap(
                    positionId
                )
            ) {
                for (
                    uint256 j = i;
                    j + 1 < length;
                    j++
                ) {
                    positions[j] =
                        positions[j + 1];
                }

                positions.pop();

                _registered[
                    compositionId
                ][
                    positionId
                ] = false;

                return;
            }
        }

        revert PositionNotFound();
    }

    //////////////////////////////////////////////////////////////
    // POSITION COUNT
    //////////////////////////////////////////////////////////////

    /// @notice Returns the number of Positions registered
    ///         for a Composition.
    /// @param compositionId Composition identifier.
    /// @return count Number of registered Positions.
    function positionCount(
        CompositionId compositionId
    )
        external
        view
        returns (
            uint256 count
        )
    {
        _validateCompositionId(
            compositionId
        );

        return
            _positions[
                compositionId
            ].length;
    }

    //////////////////////////////////////////////////////////////
    // POSITION AT
    //////////////////////////////////////////////////////////////

    /// @notice Returns a Position at a specific Composition index.
    /// @param compositionId Composition identifier.
    /// @param index Position index.
    /// @return positionId Position identifier.
    function positionAt(
        CompositionId compositionId,
        uint256 index
    )
        external
        view
        returns (
            PositionId positionId
        )
    {
        _validateCompositionId(
            compositionId
        );

        if (
            index >=
            _positions[
                compositionId
            ].length
        ) {
            revert PositionNotFound();
        }

        return
            _positions[
                compositionId
            ][
                index
            ];
    }

    //////////////////////////////////////////////////////////////
    // POSITION REGISTRATION CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position participates in a Composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    /// @return registered True when registered.
    function isRegistered(
        CompositionId compositionId,
        PositionId positionId
    )
        external
        view
        returns (
            bool registered
        )
    {
        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            return false;
        }

        if (
            PositionId.unwrap(
                positionId
            ) == 0
        ) {
            return false;
        }

        return
            _registered[
                compositionId
            ][
                positionId
            ];
    }

    //////////////////////////////////////////////////////////////
    // GET ALL POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Returns all Positions registered for a Composition.
    /// @param compositionId Composition identifier.
    /// @return positions Registered Position identifiers.
    function getPositions(
        CompositionId compositionId
    )
        external
        view
        returns (
            PositionId[] memory positions
        )
    {
        _validateCompositionId(
            compositionId
        );

        return
            _positions[
                compositionId
            ];
    }

    //////////////////////////////////////////////////////////////
    // POSITION INDEX
    //////////////////////////////////////////////////////////////

    /// @notice Returns the index of a Position within a Composition.
    /// @dev
    /// Reverts when the Position is not registered.
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    /// @return index Position index.
    function getPositionIndex(
        CompositionId compositionId,
        PositionId positionId
    )
        external
        view
        returns (
            uint256 index
        )
    {
        _validateCompositionId(
            compositionId
        );

        _validatePositionId(
            positionId
        );

        PositionId[] memory positions =
            _positions[
                compositionId
            ];

        uint256 length =
            positions.length;

        for (
            uint256 i = 0;
            i < length;
            i++
        ) {
            if (
                PositionId.unwrap(
                    positions[i]
                )
                ==
                PositionId.unwrap(
                    positionId
                )
            ) {
                return i;
            }
        }

        revert PositionNotFound();
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE COMPOSITION ID
    //////////////////////////////////////////////////////////////

    function _validateCompositionId(
        CompositionId compositionId
    )
        internal
        pure
    {
        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            revert ZeroValue();
        }
    }

    //////////////////////////////////////////////////////////////
    // VALIDATE POSITION ID
    //////////////////////////////////////////////////////////////

    function _validatePositionId(
        PositionId positionId
    )
        internal
        pure
    {
        if (
            PositionId.unwrap(
                positionId
            ) == 0
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
            msg.sender !=
            positionAuthority
        ) {
            revert Unauthorized();
        }
    }
}
