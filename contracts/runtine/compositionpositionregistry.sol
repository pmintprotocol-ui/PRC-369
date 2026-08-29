// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../kernel/Types.sol";
import "../kernel/Errors.sol";
import "../kernel/CompositionTypes.sol";

import "./PositionRegistry.sol";

/// @title PRC-369 Composition Position Registry
/// @author MINTer
/// @notice Registers the Positions participating in each Composition.
/// @dev
/// This Runtime component is responsible ONLY for the relationship:
///
///     CompositionId -> PositionId[]
///
/// It does NOT:
/// - Define Position identity.
/// - Define Composition identity.
/// - Modify Position capabilities.
/// - Modify Position lifecycle state.
/// - Modify Composition lifecycle state.
/// - Register Composition operations.
/// - Execute SPLIT.
/// - Execute MERGE.
/// - Execute COMPOSE.
/// - Transfer assets.
/// - Modify EconomicState.
/// - Calculate economic value.
/// - Perform settlement.
///
/// Position existence remains authoritative in PositionRegistry.
///
/// Composition operation compatibility remains the responsibility of
/// PositionCompositionManager.
///
/// Composition lifecycle remains the responsibility of
/// CompositionStateManager.

contract CompositionPositionRegistry {

    //////////////////////////////////////////////////////////////
    // POSITION REGISTRY
    //////////////////////////////////////////////////////////////

    /// @notice Authoritative Position registry.
    PositionRegistry public immutable positionRegistry;

    //////////////////////////////////////////////////////////////
    // AUTHORITY
    //////////////////////////////////////////////////////////////

    /// @notice Authority allowed to manage Composition participants.
    address public immutable compositionPositionAuthority;

    //////////////////////////////////////////////////////////////
    // STORAGE
    //////////////////////////////////////////////////////////////

    /// @notice Positions participating in each Composition.
    mapping(CompositionId => PositionId[])
        private _positions;

    /// @notice Tracks whether a Position is already registered
    ///         within a Composition.
    mapping(
        CompositionId =>
            mapping(PositionId => bool)
    )
        private _registered;

    //////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the Composition Position Registry.
    /// @param positionRegistryAddress Authoritative Position Registry.
    /// @param authority Authority allowed to register participants.
    constructor(
        address positionRegistryAddress,
        address authority
    ) {
        if (
            positionRegistryAddress ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            authority ==
            address(0)
        ) {
            revert ZeroAddress();
        }

        positionRegistry =
            PositionRegistry(
                positionRegistryAddress
            );

        compositionPositionAuthority =
            authority;
    }

    //////////////////////////////////////////////////////////////
    // REGISTER POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Registers a Position as a participant of a Composition.
    /// @dev
    /// The Position must already exist in PositionRegistry.
    ///
    /// This function only creates the relationship between the
    /// Composition and the Position.
    ///
    /// It does not validate whether the Position supports the
    /// Composition operation. That responsibility belongs to
    /// PositionCompositionManager.
    ///
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
    // REGISTER MULTIPLE POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Registers multiple Positions in a Composition.
    /// @dev
    /// Every Position must already exist in PositionRegistry.
    ///
    /// Duplicate Positions within the same Composition are rejected.
    ///
    /// @param compositionId Composition identifier.
    /// @param positionIds Position identifiers.
    function registerPositions(
        CompositionId compositionId,
        PositionId[] calldata positionIds
    )
        external
    {
        _authorize();

        _validateCompositionId(
            compositionId
        );

        uint256 length =
            positionIds.length;

        if (
            length == 0
        ) {
            revert ZeroValue();
        }

        for (
            uint256 i = 0;
            i < length;
            i++
        ) {
            PositionId positionId =
                positionIds[i];

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
    }

    //////////////////////////////////////////////////////////////
    // REMOVE POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Removes a Position from a Composition.
    /// @dev
    /// This only removes the Composition/Position relationship.
    /// It does not modify the Position itself.
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
                positions[i] =
                    positions[
                        length - 1
                    ];

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
    // GET POSITIONS
    //////////////////////////////////////////////////////////////

    /// @notice Returns all Positions participating in a Composition.
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

        return _positions[
            compositionId
        ];
    }

    //////////////////////////////////////////////////////////////
    // POSITION COUNT
    //////////////////////////////////////////////////////////////

    /// @notice Returns the number of Positions in a Composition.
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
        if (
            CompositionId.unwrap(
                compositionId
            ) == bytes32(0)
        ) {
            return 0;
        }

        return _positions[
            compositionId
        ].length;
    }

    //////////////////////////////////////////////////////////////
    // PARTICIPATION CHECK
    //////////////////////////////////////////////////////////////

    /// @notice Checks whether a Position participates in a Composition.
    /// @param compositionId Composition identifier.
    /// @param positionId Position identifier.
    /// @return registered True when registered.
    function isPositionRegistered(
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

        return _registered[
            compositionId
        ][
            positionId
        ];
    }

    //////////////////////////////////////////////////////////////
    // FIRST POSITION
    //////////////////////////////////////////////////////////////

    /// @notice Returns the first Position of a Composition.
    /// @dev Reverts when no Position is registered.
    /// @param compositionId Composition identifier.
    /// @return positionId First registered Position.
    function getFirstPosition(
        CompositionId compositionId
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
            _positions[
                compositionId
            ].length == 0
        ) {
            revert PositionNotFound();
        }

        return _positions[
            compositionId
        ][0];
    }

    //////////////////////////////////////////////////////////////
    // POSITION BY INDEX
    //////////////////////////////////////////////////////////////

    /// @notice Returns a Position at a specific index.
    /// @param compositionId Composition identifier.
    /// @param index Position index.
    /// @return positionId Position at the requested index.
    function getPositionAt(
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

        return _positions[
            compositionId
        ][index];
    }

    //////////////////////////////////////////////////////////////
    // INTERNAL COMPOSITION VALIDATION
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
    // INTERNAL POSITION VALIDATION
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
            compositionPositionAuthority
        ) {
            revert Unauthorized();
        }
    }
}
