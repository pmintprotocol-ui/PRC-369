// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@5.0.2/utils/ReentrancyGuard.sol";

interface IFUSEReserveRewards {
    function ownerOf(uint256 tokenId) external view returns (address);
    function rewardBeneficiary(uint256 reserveId) external view returns (address);
    function reserveStatus(uint256 reserveId) external view returns (
        bool active, bool matured, bool transferable, bool rewardEligible, uint256 cp
    );
    function getReserve(uint256 reserveId) external view returns (
        address token, uint256 amount, uint256 cp, uint256 createdAt,
        uint256 eligibleAt, uint256 unlockTime, uint256 rawAmount, bool rewardEligible
    );
    function injectReward(address rewardToken, uint256 amount) external;
}

/// @title FUSERewards
/// @author MINTer
/// @notice XCP rewards for FUSEReserve NFTs on PulseChain.
/// @dev Every distribution validates the complete active set atomically.
///      This ensures correctness but imposes O(N) gas costs; see security notes.
contract FUSERewards is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PULSECHAIN_ID = 369;
    uint256 public constant INDEX_PRECISION = 1e36;
    uint256 public constant XCP_UNIT = 5_555;
    uint256 public constant COOLDOWN = 24 hours;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    // No fixed cap: synchronization is performed in bounded batches.

    IERC20 public immutable CV;
    IERC20 public immutable FUSER;
    IFUSEReserveRewards public immutable FUSERESERVE;
    address public immutable MINTER_ADDRESS;
    uint256 public immutable REGISTRATION_FEE_FUSER;
    uint256 public immutable CV_UNIT;

    struct Boost {
        uint8 tier;
        uint64 registeredAt;
        uint256 xcp;       // Zero until cooldown is over and activation occurs.
        uint256 paidCV;
    }

    mapping(uint256 => Boost) public boosts;
    mapping(uint256 => bool) public registeredFUSErX;
    mapping(uint256 => uint256) public rewardIndex;
    mapping(uint256 => uint256) public accruedCV;
    mapping(uint256 => uint256) public fractionalRemainder;
    // Kept for backwards-compatible UI visibility; no longer used to limit earned rewards.
    mapping(uint256 => uint256) public lastVerifiedIndex;
    uint256[] private activeIds;
    mapping(uint256 => uint256) private activeIndexPlusOne;

    uint256 public totalXCP;
    uint256 public globalRewardIndex;
    uint256 public rewardLiability;
    uint256 public rewardDust; // cumulative whole CV base units actually burned as rounding dust
    uint256 public totalCVBurned;
    uint256 public totalCVPaid;
    uint256 public totalCVToMinter;
    uint256 public totalCVToPool;
    uint256 public totalCVToReserve;
    uint256 public totalCVClaimed;
    uint256 public totalFUSERInjected;
    uint256 public totalForfeitedCV;
    // All distribution snapshots are atomic; no unverified allocations are created.
    uint256 public quarantinedCV;
    mapping(uint256 => uint256) public closureUnverifiedEstimate;
    uint256 public totalForfeitedToMinter;
    uint256 public queuedCV;
    uint256 public sweepCursor;
    bool public sweepActive;
    uint256 public sweepStartBlock;
    uint256 public constant SWEEP_TIMEOUT_BLOCKS = 7200;
    // A sweep prevents XCP weight changes until completion. Deposits are queued.


    error WrongChain();
    error ZeroAddress();
    error InvalidContract();
    error InvalidTokenDecimals();
    error InvalidTier();
    error InvalidReserve();
    error NotReserveOwner();
    error ReserveNotEligible();
    error TierNotHigher();
    error NotRegistered();
    error AlreadyRegistered();
    error StillCooling();
    error AlreadyActivated();
    error NoReward();
    error ExactTransferRequired();
    error Insolvent();
    error SweepInProgress();
    error SweepNotInProgress();
    error InvalidBatch();
    error NoActiveXCP();
    error SweepNotExpired();
    error PendingDistribution();
    error NothingToSettle();
    error InvalidXCPState();
    error UnregisteredClaim();
    error ArrayLengthZero();
    error DuplicateReserveId();
    error ClaimExceedsAccrued();

    event FUSErXRegistered(uint256 indexed reserveId, address indexed owner, uint256 fuserInjected, uint256 cvToMinter, uint256 cvToReserve, uint256 cooldownEnd);
    event FUSErXActivated(uint256 indexed reserveId, address indexed owner, uint8 tier, uint256 xcp);
    event FUSErXUpgraded(uint256 indexed reserveId, address indexed owner, uint8 oldTier, uint8 newTier, uint256 payment, uint256 toMinter, uint256 toPool, uint256 toReserve);
    event RewardDistributed(uint256 amount, uint256 indexed xcpSnapshot, uint256 indexIncrease, uint256 roundingDust);
    event RoundingDustBurned(uint256 amount);
    event RewardClaimed(uint256 indexed reserveId, address indexed beneficiary, uint256 amount);
    event BoostDeactivated(uint256 indexed reserveId, address indexed beneficiary, uint256 removedXCP);
    event ExternalRewardInjected(address indexed payer, uint256 amount);
    event SweepStarted(uint256 indexed blockNumber, uint256 positions);
    event SweepProgress(uint256 cursor, uint256 remaining);
    event SweepCompleted(uint256 remainingXCP, uint256 distributedCV);
    event RewardQueued(uint256 amount);
    event SweepAborted(uint256 indexed startBlock);
    event ClosedRewardQuarantined(uint256 indexed reserveId, uint256 estimatedAmount);
    event ForfeitedRewardSentToMinter(uint256 amount);
    event ClosedReservesSynced(uint256 examined, uint256 deactivated);
    event PartialRewardClaimed(uint256 indexed reserveId, address indexed beneficiary, uint256 amount);

    constructor(address cvToken, address fuserToken, address fusereserve, address minterAddress) {
        if (block.chainid != PULSECHAIN_ID) revert WrongChain();
        if (cvToken == address(0) || fuserToken == address(0) || fusereserve == address(0) || minterAddress == address(0)) revert ZeroAddress();
        if (cvToken.code.length == 0 || fuserToken.code.length == 0 || fusereserve.code.length == 0) revert InvalidContract();
        uint8 cvDecimals = _readDecimals(cvToken);
        uint8 fuserDecimals = _readDecimals(fuserToken);
        CV = IERC20(cvToken);
        FUSER = IERC20(fuserToken);
        FUSERESERVE = IFUSEReserveRewards(fusereserve);
        MINTER_ADDRESS = minterAddress;
        CV_UNIT = 10 ** uint256(cvDecimals);
        REGISTRATION_FEE_FUSER = 369 * (10 ** uint256(fuserDecimals));
    }

    /// @notice First registration: 369 FUSEr to FUSEReserve, 50% CV to MINTer,
    ///         50% CV to FUSEReserve. The position starts a 24-hour cooldown.
    function registerFUSErX(uint256 reserveId, uint8 tier) external nonReentrant {
        if (registeredFUSErX[reserveId]) revert AlreadyRegistered();
        if (tier < 1 || tier > 5) revert InvalidTier();
        _validateOwnedEligibleReserve(reserveId, msg.sender);

        uint256 payment = _tierCost(tier);
        uint256 toMinter = payment / 2;
        uint256 toReserve = payment - toMinter;

        _pullExact(FUSER, msg.sender, REGISTRATION_FEE_FUSER);
        _inject(FUSER, REGISTRATION_FEE_FUSER);
        totalFUSERInjected += REGISTRATION_FEE_FUSER;

        _pullExact(CV, msg.sender, payment);
        CV.safeTransfer(MINTER_ADDRESS, toMinter);
        _inject(CV, toReserve);
        totalCVPaid += payment;
        totalCVToMinter += toMinter;
        totalCVToReserve += toReserve;

        registeredFUSErX[reserveId] = true;
        boosts[reserveId] = Boost({
            tier: tier, registeredAt: uint64(block.timestamp), xcp: 0, paidCV: payment
        });
        rewardIndex[reserveId] = globalRewardIndex;
        emit FUSErXRegistered(reserveId, msg.sender, REGISTRATION_FEE_FUSER, toMinter, toReserve, block.timestamp + COOLDOWN);
        _assertSolvent();
    }

    /// @notice Activate after 24 hours. Matured but unbroken reserves are valid.
    function activateXCP(uint256 reserveId) external nonReentrant {
        Boost storage b = boosts[reserveId];
        if (!registeredFUSErX[reserveId] || b.tier == 0) revert NotRegistered();
        if (b.xcp != 0) revert AlreadyActivated();
        if (block.timestamp < uint256(b.registeredAt) + COOLDOWN) revert StillCooling();
        _validateOwnedEligibleReserve(reserveId, msg.sender);
        if (sweepActive) revert SweepInProgress();
        if (queuedCV != 0) revert PendingDistribution();
        _syncOne(reserveId);
        b.xcp = XCP_UNIT * uint256(b.tier);
        rewardIndex[reserveId] = globalRewardIndex;
        lastVerifiedIndex[reserveId] = globalRewardIndex;
        totalXCP += b.xcp;
        _addActive(reserveId);
        emit FUSErXActivated(reserveId, msg.sender, b.tier, b.xcp);
        _assertSolvent();
    }

    /// @notice Pay only the difference to a higher tier.
    /// @dev Upgrades are permitted only after the original 24-hour cooldown.
    ///      Once eligible, the owner may upgrade directly to any higher tier,
    ///      paying only the difference; no additional cooldown is imposed.
    function upgradeFUSErX(uint256 reserveId, uint8 newTier) external nonReentrant {
        if (newTier < 1 || newTier > 5) revert InvalidTier();
        Boost storage b = boosts[reserveId];
        if (!registeredFUSErX[reserveId] || b.tier == 0) revert NotRegistered();
        if (newTier <= b.tier) revert TierNotHigher();
        if (block.timestamp < uint256(b.registeredAt) + COOLDOWN) revert StillCooling();
        _validateOwnedEligibleReserve(reserveId, msg.sender);

        uint8 oldTier = b.tier;
        uint256 payment = _tierCost(newTier) - _tierCost(oldTier);
        uint256 toMinter = payment / 2;
        uint256 poolHalf = payment - toMinter;
        uint256 toPool;
        uint256 toReserve;

        if (sweepActive) revert SweepInProgress();
        if (queuedCV != 0) revert PendingDistribution();
        // Upgrades are only possible after cooldown; activation may still be pending.
        if (b.xcp != 0) {
            _syncOne(reserveId);
            if (b.xcp == 0) revert InvalidReserve();
            _accrue(reserveId, b);
            lastVerifiedIndex[reserveId] = globalRewardIndex;
            toPool = poolHalf;
        } else {
            toReserve = poolHalf;
        }

        _pullExact(CV, msg.sender, payment);
        CV.safeTransfer(MINTER_ADDRESS, toMinter);
        if (toReserve != 0) _inject(CV, toReserve);
        if (toPool != 0) _queueReward(toPool);

        if (b.xcp != 0) {
            totalXCP = totalXCP - b.xcp + XCP_UNIT * uint256(newTier);
            b.xcp = XCP_UNIT * uint256(newTier);
            rewardIndex[reserveId] = globalRewardIndex;
        }
        b.tier = newTier;
        b.paidCV = _tierCost(newTier);
        totalCVPaid += payment;
        totalCVToMinter += toMinter;
        totalCVToPool += toPool;
        totalCVToReserve += toReserve;
        emit FUSErXUpgraded(reserveId, msg.sender, oldTier, newTier, payment, toMinter, toPool, toReserve);
        _assertSolvent();
    }

    /// @notice Inject CV for active XCP holders; if none exist at settlement, forward to MINTer.
    /// @dev Deposits are queued until a bounded synchronization cycle is finalized.
    function injectReward(uint256 amount) external nonReentrant {
        if (amount == 0) revert NoReward();
        _pullExact(CV, msg.sender, amount);
        _queueReward(amount);
        totalCVToPool += amount;
        emit ExternalRewardInjected(msg.sender, amount);
        _assertSolvent();
    }

    /// @notice Anyone can synchronize a closed reserve, including matured-then-redeemed NFTs.
    function syncReserve(uint256 reserveId) external nonReentrant {
        if (sweepActive) revert SweepInProgress();
        Boost storage b = boosts[reserveId];
        if (b.xcp == 0) return;
        if (!_isOpen(reserveId)) _deactivate(reserveId);
        _assertSolvent();
    }

    /// @notice Permissionless batch cleanup of specifically identified closed reserves.
    /// @dev Does not distribute rewards or modify historical allocation snapshots.
    ///      Useful for off-chain keepers watching ReserveCompleted/EmergencyExit.
    ///      During an active sweep, state changes are deferred to avoid cursor corruption.
    function syncClosedReserves(uint256[] calldata reserveIds)
        external nonReentrant returns (uint256 deactivated)
    {
        if (sweepActive) revert SweepInProgress();
        if (reserveIds.length == 0) revert ArrayLengthZero();
        for (uint256 i; i < reserveIds.length; ++i) {
            uint256 id = reserveIds[i];
            if (boosts[id].xcp != 0 && !_isOpen(id)) {
                _deactivate(id);
                unchecked { ++deactivated; }
            }
        }
        emit ClosedReservesSynced(reserveIds.length, deactivated);
        _assertSolvent();
    }

    /// @notice Verify actual open status without modifying accounting.
    /// @dev The result is current only at the transaction/block being queried.
    function reserveXCPStatus(uint256 reserveId)
        external view returns (bool registered, bool open, uint256 nominalXCP, uint256 effectiveXCP)
    {
        registered = registeredFUSErX[reserveId];
        nominalXCP = boosts[reserveId].xcp;
        if (nominalXCP != 0) {
            open = _isOpen(reserveId);
            if (open) effectiveXCP = nominalXCP;
        }
    }

    /// @notice True only if the full atomic validation can be attempted.
    /// @dev Callers must supply an appropriate transaction gas limit.
    function sweepReady() external view returns (bool ready, uint256 activePositions, uint256 queuedRewards) {
        ready = sweepActive && sweepCursor >= activeIds.length;
        activePositions = activeIds.length;
        queuedRewards = queuedCV;
    }

    /// @notice Begin a bounded synchronization cycle. No single call iterates all NFTs.
    function startSweep() external nonReentrant {
        if (sweepActive) revert SweepInProgress();
        if (queuedCV == 0) revert NothingToSettle();
        sweepActive = true;
        sweepCursor = 0;
        sweepStartBlock = block.number;
        emit SweepStarted(block.number, activeIds.length);
    }

    /// @notice Scan up to maxSteps positions; swap/pop removals do not skip an ID.
    function sweepBatch(uint256 maxSteps) external nonReentrant returns (bool complete) {
        if (!sweepActive) revert SweepNotInProgress();
        if (maxSteps == 0 || maxSteps > 256) revert InvalidBatch();
        uint256 steps;
        while (steps < maxSteps && sweepCursor < activeIds.length) {
            uint256 id = activeIds[sweepCursor];
            if (!_isOpen(id)) _deactivate(id);
            else {
                unchecked { ++sweepCursor; }
            }
            unchecked { ++steps; }
        }
        complete = sweepCursor >= activeIds.length;
        emit SweepProgress(sweepCursor, activeIds.length - sweepCursor);
        _assertSolvent();
    }

    /// @notice Recover from a stalled sweep without distributing queued funds.
    /// @dev Progressively removed closed positions remain removed; no new index is created.
    function abortExpiredSweep() external nonReentrant {
        if (!sweepActive) revert SweepNotInProgress();
        if (block.number <= sweepStartBlock + SWEEP_TIMEOUT_BLOCKS) revert SweepNotExpired();
        uint256 oldStart = sweepStartBlock;
        sweepActive = false;
        sweepCursor = 0;
        emit SweepAborted(oldStart);
    }

    /// @notice Fastest safe settlement available without a lifecycle hook in FUSEReserve.
    /// @dev One O(N) read-only status pass; no redundant preliminary sweep and
    ///      no storage writes for positions that remain open.
    ///      A closed reserve is removed before the distribution snapshot.
    function settleAtomic() external nonReentrant {
        if (sweepActive) revert SweepInProgress();
        if (queuedCV == 0) revert NothingToSettle();
        _settleAtomic();
    }

    /// @notice Legacy batch workflow settlement, preserving the existing ABI.
    /// @dev The earlier batch cannot be trusted as a final snapshot; closures
    ///      may occur after it. Thus finalization still validates all live IDs.
    function finalizeSweep() external nonReentrant {
        if (!sweepActive) revert SweepNotInProgress();
        if (sweepCursor < activeIds.length) revert SweepInProgress();
        _settleAtomic();
    }

    function _settleAtomic() internal {
        uint256 cursor;
        while (cursor < activeIds.length) {
            uint256 id = activeIds[cursor];
            if (!_isOpen(id)) {
                _deactivate(id); // swap/pop: check the replacement at this index
            } else {
                unchecked { ++cursor; }
            }
        }

        uint256 amount = queuedCV;
        queuedCV = 0;
        sweepActive = false;
        sweepCursor = 0;
        if (amount != 0) {
            if (totalXCP == 0) {
                CV.safeTransfer(MINTER_ADDRESS, amount);
                totalForfeitedToMinter += amount;
            } else {
                _distributeNow(amount);
            }
        }
        emit SweepCompleted(totalXCP, amount);
        _assertSolvent();
    }

    /// @notice Legacy convenience function: start a new batch cycle.
    function syncAll() external nonReentrant {
        if (sweepActive) revert SweepInProgress();
        if (queuedCV == 0) revert NothingToSettle();
        sweepActive = true;
        sweepCursor = 0;
        sweepStartBlock = block.number;
        emit SweepStarted(block.number, activeIds.length);
    }

    /// @notice Claim all CV earned in prior atomically validated distributions.
    /// @dev Claimable after cooldown, including during sweeps and after closure.
    function claim(uint256 reserveId) external nonReentrant returns (uint256 amount) {
        Boost storage b = boosts[reserveId];
        if (!registeredFUSErX[reserveId]) revert UnregisteredClaim();
        address beneficiary = FUSERESERVE.rewardBeneficiary(reserveId);
        if (beneficiary == address(0)) revert InvalidReserve();
        if (beneficiary != msg.sender) revert NotReserveOwner();
        if (block.timestamp < uint256(b.registeredAt) + COOLDOWN) revert StillCooling();

        // Past distributions checked every active reserve in the same tx.
        // Consequently all past index rewards were earned even if closed now.
        if (b.xcp != 0) {
            if (!_isOpen(reserveId)) _deactivate(reserveId);
            else _accrue(reserveId, b);
        }
        amount = accruedCV[reserveId];
        if (amount == 0) revert NoReward();
        accruedCV[reserveId] = 0;
        rewardLiability -= amount;
        totalCVClaimed += amount;
        CV.safeTransfer(beneficiary, amount);
        _assertSolvent();
        emit RewardClaimed(reserveId, beneficiary, amount);
    }

    /// @notice Claim a selected number of already accrued CV units after cooldown.
    /// @dev The position is checked and accrued using only completed atomic snapshots.
    ///      Closed positions retain historical claim rights through rewardBeneficiary.
    function claimAmount(uint256 reserveId, uint256 requested)
        external nonReentrant returns (uint256 paid)
    {
        if (requested == 0) revert NoReward();
        Boost storage b = boosts[reserveId];
        if (!registeredFUSErX[reserveId]) revert UnregisteredClaim();
        address beneficiary = FUSERESERVE.rewardBeneficiary(reserveId);
        if (beneficiary == address(0)) revert InvalidReserve();
        if (beneficiary != msg.sender) revert NotReserveOwner();
        if (block.timestamp < uint256(b.registeredAt) + COOLDOWN) revert StillCooling();
        if (b.xcp != 0) {
            if (!_isOpen(reserveId)) _deactivate(reserveId);
            else _accrue(reserveId, b);
        }
        if (requested > accruedCV[reserveId]) revert ClaimExceedsAccrued();
        accruedCV[reserveId] -= requested;
        rewardLiability -= requested;
        totalCVClaimed += requested;
        CV.safeTransfer(beneficiary, requested);
        _assertSolvent();
        emit RewardClaimed(reserveId, beneficiary, requested);
        emit PartialRewardClaimed(reserveId, beneficiary, requested);
        return requested;
    }

    function pendingReward(uint256 reserveId) external view returns (uint256) {
        Boost memory b = boosts[reserveId];
        uint256 amount = accruedCV[reserveId];
        if (b.xcp == 0 || globalRewardIndex <= rewardIndex[reserveId]) return amount;
        // All published index increases came from atomic eligibility snapshots.
        uint256 scaled = b.xcp * (globalRewardIndex - rewardIndex[reserveId]) + fractionalRemainder[reserveId];
        return amount + scaled / INDEX_PRECISION;
    }

    function activeCount() external view returns (uint256) { return activeIds.length; }
    function activeIdAt(uint256 index) external view returns (uint256) { return activeIds[index]; }
    function xcpOf(uint256 reserveId) external view returns (uint256) { return boosts[reserveId].xcp; }
    function tierCost(uint8 tier) external view returns (uint256) {
        if (tier > 5) revert InvalidTier();
        return _tierCost(tier);
    }
    function cooldownEnds(uint256 reserveId) external view returns (uint256) {
        if (!registeredFUSErX[reserveId]) return 0;
        return uint256(boosts[reserveId].registeredAt) + COOLDOWN;
    }
    // Liability includes each distribution's rounded-up index allocation.
    // Fractional index units are not ERC20 units and are never individually burned.
    // Proof of claim coverage requires testing changing weights and index checkpoints.
    function requiredCVBalance() public view returns (uint256) { return rewardLiability + queuedCV; }
    function solvent() external view returns (bool) { return CV.balanceOf(address(this)) >= requiredCVBalance(); }

    function _syncOne(uint256 reserveId) internal {
        if (boosts[reserveId].xcp != 0) {
            if (!_isOpen(reserveId)) _deactivate(reserveId);
            // No write needed for an open reserve: distribution checkpoints
            // are established atomically by settleAtomic/finalizeSweep.
        }
    }

    function _queueReward(uint256 amount) internal {
        queuedCV += amount;
        emit RewardQueued(amount);
    }

    /// @dev IMPORTANT: requires reserveStatus.active to mean 'not broken or redeemed',
    ///      INCLUDING matured but still existing reserves. Verify against deployed ABI.
    function _isOpen(uint256 reserveId) internal view returns (bool) {
        try FUSERESERVE.reserveStatus(reserveId) returns (
            bool active, bool, bool, bool, uint256
        ) { return active; } catch { revert InvalidReserve(); }
    }

    function _deactivate(uint256 reserveId) internal {
        Boost storage b = boosts[reserveId];
        if (b.xcp == 0) { _removeActive(reserveId); return; }
        // Every past reward distribution verified this reserve as open at its
        // transaction snapshot. Its historical entitlement is therefore valid.
        _accrue(reserveId, b);
        lastVerifiedIndex[reserveId] = globalRewardIndex;
        fractionalRemainder[reserveId] = 0;
        uint256 removed = b.xcp;
        totalXCP -= removed;
        b.xcp = 0;
        _removeActive(reserveId);
        address beneficiary = FUSERESERVE.rewardBeneficiary(reserveId);
        emit BoostDeactivated(reserveId, beneficiary, removed);
    }

    function _addActive(uint256 reserveId) internal {
        if (activeIndexPlusOne[reserveId] != 0) return;
        activeIds.push(reserveId);
        activeIndexPlusOne[reserveId] = activeIds.length;
    }

    function _removeActive(uint256 reserveId) internal {
        uint256 plusOne = activeIndexPlusOne[reserveId];
        if (plusOne == 0) return;
        uint256 index = plusOne - 1;
        uint256 lastIndex = activeIds.length - 1;
        if (index != lastIndex) {
            uint256 lastId = activeIds[lastIndex];
            activeIds[index] = lastId;
            activeIndexPlusOne[lastId] = index + 1;
        }
        activeIds.pop();
        delete activeIndexPlusOne[reserveId];
    }

    function _validateOwnedEligibleReserve(uint256 reserveId, address user) internal view {
        address owner;
        try FUSERESERVE.ownerOf(reserveId) returns (address o) { owner = o; }
        catch { revert InvalidReserve(); }
        if (owner != user) revert NotReserveOwner();
        try FUSERESERVE.reserveStatus(reserveId) returns (
            bool active, bool, bool, bool rewardEligible, uint256
        ) {
            if (!active) revert InvalidReserve();
            if (!rewardEligible) revert ReserveNotEligible();
        } catch { revert InvalidReserve(); }
        try FUSERESERVE.getReserve(reserveId) returns (
            address token, uint256, uint256, uint256, uint256 eligibleAt, uint256, uint256, bool rewardEligible
        ) {
            if (token == address(0)) revert InvalidReserve();
            if (!rewardEligible || block.timestamp < eligibleAt) revert ReserveNotEligible();
        } catch { revert InvalidReserve(); }
    }

    function _pullExact(IERC20 token, address from, uint256 amount) internal {
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        if (token.balanceOf(address(this)) - beforeBalance != amount) revert ExactTransferRequired();
    }

    function _inject(IERC20 token, uint256 amount) internal {
        token.forceApprove(address(FUSERESERVE), amount);
        FUSERESERVE.injectReward(address(token), amount);
        token.forceApprove(address(FUSERESERVE), 0);
    }

    function _accrue(uint256 reserveId, Boost storage b) internal {
        _accrueTo(reserveId, b, globalRewardIndex);
    }

    function _accrueTo(uint256 reserveId, Boost storage b, uint256 idx) internal {
        uint256 last = rewardIndex[reserveId];
        if (b.xcp != 0 && idx > last) {
            uint256 scaled = b.xcp * (idx - last) + fractionalRemainder[reserveId];
            uint256 whole = scaled / INDEX_PRECISION;
            fractionalRemainder[reserveId] = scaled % INDEX_PRECISION;
            if (whole != 0) accruedCV[reserveId] += whole;
        }
        rewardIndex[reserveId] = idx;
    }

    function _distributeNow(uint256 amount) internal {
        if (amount == 0) return;
        uint256 snapshot = totalXCP;
        if (snapshot == 0) revert NoActiveXCP();
        uint256 increase = amount * INDEX_PRECISION / snapshot;
        if (increase == 0) revert NoReward();
        // Reserve the CEILING of the global index entitlement, not the floor.
        // Position-level fractional remainders can mature across multiple rounds;
        // reserving only floor(indexDelta * totalXCP) can underfund later claims.
        uint256 scaledEntitlement = increase * snapshot;
        uint256 reserved = scaledEntitlement / INDEX_PRECISION;
        if (scaledEntitlement % INDEX_PRECISION != 0) ++reserved;
        // Only whole token base units provably OUTSIDE the index entitlement
        // may be burned. Per-NFT fractionalRemainder is NOT burnable CV.
        uint256 dust = amount - reserved;
        globalRewardIndex += increase;
        rewardLiability += reserved;
        if (dust != 0) {
            rewardDust += dust;
            totalCVBurned += dust;
            CV.safeTransfer(BURN_ADDRESS, dust);
            emit RoundingDustBurned(dust);
        }
        emit RewardDistributed(amount, snapshot, increase, dust);
    }

    function _tierCost(uint8 tier) internal view returns (uint256) {
        if (tier == 0) return 0;
        if (tier == 1) return 1_000 * CV_UNIT;
        if (tier == 2) return 2_000 * CV_UNIT;
        if (tier == 3) return 4_000 * CV_UNIT;
        if (tier == 4) return 8_000 * CV_UNIT;
        if (tier == 5) return 10_000 * CV_UNIT;
        revert InvalidTier();
    }

    function _readDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            if (d > 18) revert InvalidTokenDecimals();
            return d;
        } catch { revert InvalidTokenDecimals(); }
    }

    function _assertSolvent() internal view {
        if (CV.balanceOf(address(this)) < requiredCVBalance()) revert Insolvent();
    }
}
