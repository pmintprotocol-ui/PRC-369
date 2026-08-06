// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PRC-369 Kernel Constants
/// @author MINTer Protocol
/// @notice Defines immutable global constants used across the PRC-369 Kernel.
/// @dev This library contains protocol-wide constants only.
///      It MUST NEVER contain storage, logic, state variables,
///      external calls or configuration values.
library Constants {

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL
    //////////////////////////////////////////////////////////////*/

    /// @notice PRC standard name.
    string internal constant STANDARD = "PRC-369";

    /// @notice Reference implementation name.
    string internal constant PROTOCOL = "MINTer";

    /// @notice Native deployment chain.
    uint256 internal constant PULSECHAIN_CHAIN_ID = 369;

    /// @notice Unique identifier for the PRC standard.
    bytes32 internal constant STANDARD_ID = keccak256("PRC-369");

    /// @notice Unique identifier for the reference implementation.
    bytes32 internal constant PROTOCOL_ID = keccak256("MINTer");

    /*//////////////////////////////////////////////////////////////
                            VERSION
    //////////////////////////////////////////////////////////////*/

    /// @notice Major version.
    uint16 internal constant VERSION_MAJOR = 1;

    /// @notice Minor version.
    uint16 internal constant VERSION_MINOR = 0;

    /// @notice Patch version.
    uint16 internal constant VERSION_PATCH = 0;

    /*//////////////////////////////////////////////////////////////
                            PRECISION
    //////////////////////////////////////////////////////////////*/

    /// @notice Basis points precision (100% = 10,000).
    uint256 internal constant BPS = 10_000;

    /// @notice Fixed-point precision (18 decimals).
    uint256 internal constant WAD = 1e18;

    /// @notice High precision fixed-point (27 decimals).
    uint256 internal constant RAY = 1e27;

    /*//////////////////////////////////////////////////////////////
                          KERNEL LIMITS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum supported capability flags.
    uint16 internal constant MAX_CAPABILITY_FLAGS = 256;

    /// @notice Maximum protocol generation.
    uint64 internal constant MAX_GENERATION = type(uint64).max;

    /*//////////////////////////////////////////////////////////////
                            NAMESPACES
    //////////////////////////////////////////////////////////////*/

    /// @notice Position namespace.
    bytes32 internal constant POSITION_NAMESPACE =
        keccak256("POSITION");

    /// @notice Rights namespace.
    bytes32 internal constant RIGHTS_NAMESPACE =
        keccak256("RIGHTS");

    /// @notice Vault namespace.
    bytes32 internal constant VAULT_NAMESPACE =
        keccak256("VAULT");

    /// @notice Ledger namespace.
    bytes32 internal constant LEDGER_NAMESPACE =
        keccak256("LEDGER");

    /// @notice Settlement namespace.
    bytes32 internal constant SETTLEMENT_NAMESPACE =
        keccak256("SETTLEMENT");

    /// @notice Evolution namespace.
    bytes32 internal constant EVOLUTION_NAMESPACE =
        keccak256("EVOLUTION");

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL DNA
    //////////////////////////////////////////////////////////////*/

    /// @notice Capital remains in the native reserve.
    bool internal constant CAPITAL_IMMUTABLE = true;

    /// @notice Economic rights are programmable.
    bool internal constant RIGHTS_PROGRAMMABLE = true;

    /// @notice Position history is append-only.
    bool internal constant HISTORY_APPEND_ONLY = true;

    /// @notice Economic value must always be conserved.
    bool internal constant ECONOMIC_CONSERVATION = true;
}
