// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./CompositionTypes.sol";

/// @title PRC-369 Composition Operations
/// @author MINTer
/// @notice Defines the canonical composition operation identifiers
/// recognized by PRC-369.
/// @dev
/// Part of the immutable PRC-369 Kernel.
///
/// DESIGN PRINCIPLES
/// - No storage
/// - No functions
/// - No structs
/// - No enums
/// - No events
/// - No errors
///
/// This library defines semantic operation identifiers only.
/// Runtime modules are responsible for enforcing the rules associated
/// with each operation.

library CompositionOperations {

    //////////////////////////////////////////////////////////////
    // SPLIT
    //////////////////////////////////////////////////////////////

    /// @notice Splits one Position into multiple Positions.
    CompositionOperationId internal constant SPLIT =
        CompositionOperationId.wrap(
            keccak256("PRC-369.COMPOSITION.SPLIT")
        );

    //////////////////////////////////////////////////////////////
    // MERGE
    //////////////////////////////////////////////////////////////

    /// @notice Merges multiple Positions into a resulting Position.
    CompositionOperationId internal constant MERGE =
        CompositionOperationId.wrap(
            keccak256("PRC-369.COMPOSITION.MERGE")
        );

    //////////////////////////////////////////////////////////////
    // COMPOSE
    //////////////////////////////////////////////////////////////

    /// @notice Composes multiple Positions into a composed Position.
    CompositionOperationId internal constant COMPOSE =
        CompositionOperationId.wrap(
            keccak256("PRC-369.COMPOSITION.COMPOSE")
        );
}
