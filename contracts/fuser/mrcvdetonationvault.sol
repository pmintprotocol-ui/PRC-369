// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface for the fixed PICKAXE ERC-20.
interface IERC20MrCV {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @notice Functions used by the verified FUSEReserve on PulseChain.
interface IFUSEReserveMrCV {
    function version() external pure returns (string memory);
    function isTokenRegistered(address token) external view returns (bool);
    function currentEligibleCP() external view returns (uint256);
    function injectReward(address rewardToken, uint256 amount) external;
}

/// @title MrCVDetonationVault
/// @author MINTer
/// @notice Mr. CV — The FUSEr Mining Meme; The First Meme of FUSE V2.
/// @dev Immutable 33-day PICKAXE war chest. No owner, pause, upgrade,
///      withdrawal, fee, or mint authority. Anyone may deposit or detonate.
///      FUSEReserve alone accounts for reward eligibility and distribution.
contract MrCVDetonationVault {
    string public constant AUTHOR = "MINTer";
    string public constant CHARACTER = "Mr. CV";
    string public constant MEME_IDENTITY = "The FUSEr Mining Meme";
    string public constant MEME_LEGACY = "The First Meme of FUSE V2";
    string public constant PURPOSE = "PICKAXE War Chest for FUSEReserve";

    uint256 public constant PULSECHAIN_CHAIN_ID = 369;
    uint256 public constant CYCLE = 33 days;
    address public constant PICKAXE = 0xa4F7DEA34d7b06E3aEeB72ef93A508aa60830e5D;
    // Source-verified FUSEReserve supplied by the protocol author:
    // https://repo.sourcify.dev/369/0x21d32798d2cb14b2C2c64FD5C319fc674a7B5611
    address public constant FUSERESERVE = 0x21d32798d2cb14b2C2c64FD5C319fc674a7B5611;

    uint256 public immutable genesisTime;
    uint256 public nextDetonationAt;
    uint256 public detonations;
    uint256 public totalDonatedThroughFunction;
    uint256 public totalDetonated;
    uint256 private _entered;

    event PickaxeDeposited(address indexed donor, uint256 amount);
    event Detonated(
        address indexed caller,
        uint256 indexed cycleNumber,
        uint256 amount,
        uint256 timestamp,
        uint256 nextDetonationAt
    );

    error WrongChain(uint256 actual);
    error MissingContract(address target);
    error WrongReserveIdentity();
    error PickaxeNotRegistered();
    error LockedUntil(uint256 timestamp);
    error EmptyVault();
    error NoEligibleCP();
    error Reentrant();
    error TokenCallFailed();
    error UnexpectedTokenBalance();
    error UnexpectedAllowance();

    constructor() {
        if (block.chainid != PULSECHAIN_CHAIN_ID) revert WrongChain(block.chainid);
        if (PICKAXE.code.length == 0) revert MissingContract(PICKAXE);
        if (FUSERESERVE.code.length == 0) revert MissingContract(FUSERESERVE);

        // Operational guard only: this string is NOT cryptographic code identity.
        try IFUSEReserveMrCV(FUSERESERVE).version() returns (string memory v) {
            if (keccak256(bytes(v)) != keccak256(bytes("FUSEReserve"))) {
                revert WrongReserveIdentity();
            }
        } catch {
            revert WrongReserveIdentity();
        }
        if (!IFUSEReserveMrCV(FUSERESERVE).isTokenRegistered(PICKAXE)) {
            revert PickaxeNotRegistered();
        }
        genesisTime = block.timestamp;
        nextDetonationAt = block.timestamp + CYCLE;
    }

    modifier nonReentrant() {
        if (_entered != 0) revert Reentrant();
        _entered = 1;
        _;
        _entered = 0;
    }

    /// @notice Donate PICKAXE with an attribution event.
    /// @dev Any future contract can also send PICKAXE directly with ERC20.transfer.
    ///      No integration permission, whitelist, or upgrade is required.
    /// @dev Direct ERC-20 transfers to this vault also count toward the next detonation.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert EmptyVault();
        uint256 beforeBalance = _balance();
        _safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBalance = _balance();
        if (afterBalance < beforeBalance || afterBalance - beforeBalance != amount) {
            revert UnexpectedTokenBalance();
        }
        totalDonatedThroughFunction += amount;
        emit PickaxeDeposited(msg.sender, amount);
    }

    /// @notice After 33 days, anyone may inject all PICKAXE held at entry.
    /// @dev FUSEReserve may require separate syncEligibleCP(maxSteps) calls first.
    ///      Any failed injection reverts all state changes and allowances atomically.
    function detonate() external nonReentrant returns (uint256 amount) {
        if (block.timestamp < nextDetonationAt) revert LockedUntil(nextDetonationAt);
        amount = _balance();
        if (amount == 0) revert EmptyVault();

        IFUSEReserveMrCV reserve = IFUSEReserveMrCV(FUSERESERVE);
        if (!reserve.isTokenRegistered(PICKAXE)) revert PickaxeNotRegistered();
        // FUSEReserve's injectReward() synchronizes up to MAX_SYNC_STEPS
        // and reverts with EligibilitySyncRequired if matured positions remain.
        // Its internal readiness check correctly permits still-cooling reserves.
        // Do NOT compare eligibilityCursor against nextReserveId here.
        // No preliminary currentEligibleCP() scan: the reserve itself
        // authoritatively checks totalEligibleCP after synchronization.

        uint256 cycleNumber = detonations + 1;
        uint256 nextTime = block.timestamp + CYCLE;
        detonations = cycleNumber;
        nextDetonationAt = nextTime;
        totalDetonated += amount;

        // Exact, temporary allowance; the reserve pulls PICKAXE via transferFrom.
        _safeApprove(0);
        _safeApprove(amount);
        uint256 beforeInjection = _balance();
        reserve.injectReward(PICKAXE, amount);

        // Confirm exactly `amount` left the vault. Any newly received tokens
        // (possible only with nonstandard token behavior) remain for next cycle.
        uint256 afterInjection = _balance();
        if (afterInjection > beforeInjection ||
            beforeInjection - afterInjection != amount) {
            revert UnexpectedTokenBalance();
        }
        _safeApprove(0);
        if (IERC20MrCV(PICKAXE).allowance(address(this), FUSERESERVE) != 0) {
            revert UnexpectedAllowance();
        }
        emit Detonated(msg.sender, cycleNumber, amount, block.timestamp, nextTime);
    }

    /// @notice Advisory only: use an eth_call simulation of detonate()
    ///         to confirm reward synchronization and other reserve checks.
    function canDetonate() external view returns (bool) {
        return block.timestamp >= nextDetonationAt
            && _balance() > 0
            && IFUSEReserveMrCV(FUSERESERVE).isTokenRegistered(PICKAXE)
            && IFUSEReserveMrCV(FUSERESERVE).currentEligibleCP() > 0;
    }

    function vaultBalance() external view returns (uint256) {
        return _balance();
    }

    function secondsUntilDetonation() external view returns (uint256) {
        return block.timestamp >= nextDetonationAt ? 0 : nextDetonationAt - block.timestamp;
    }

    function _balance() private view returns (uint256) {
        return IERC20MrCV(PICKAXE).balanceOf(address(this));
    }

    function _safeTransferFrom(address from, address to, uint256 amount) private {
        (bool ok, bytes memory data) = PICKAXE.call(
            abi.encodeWithSelector(IERC20MrCV.transferFrom.selector, from, to, amount)
        );
        if (!ok || !_optionalReturnSuccess(data)) revert TokenCallFailed();
    }

    function _safeApprove(uint256 amount) private {
        (bool ok, bytes memory data) = PICKAXE.call(
            abi.encodeWithSelector(IERC20MrCV.approve.selector, FUSERESERVE, amount)
        );
        if (!ok || !_optionalReturnSuccess(data)) revert TokenCallFailed();
    }

    function _optionalReturnSuccess(bytes memory data) private pure returns (bool) {
        if (data.length == 0) return true;
        if (data.length != 32) return false;
        uint256 word;
        assembly { word := mload(add(data, 32)) }
        return word == 1;
    }
}
