// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@5.0.2/utils/ReentrancyGuard.sol";
interface IFUSEReserveRewardSink {
    function injectReward(address rewardToken, uint256 amount) external;
}
/// @title FUSEReactor
/// @author MINTer
/// @notice Programmable FUSEr positions for PulseChain.
/// @dev Developed by MINTer.
contract FUSEReactor is ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant PULSECHAIN_ID = 369;
    uint256 public constant COOLING_PERIOD = 24 hours;
    uint256 public constant INDEX_PRECISION = 1e36;
    IERC20 public immutable FUSER;
    IERC20 public immutable CV;
    IERC20 public immutable DAI;
    IFUSEReserveRewardSink public immutable FUSERESERVE;
    address public immutable MINTER_ADDRESS;
    uint8 public immutable FUSER_DECIMALS;
    uint256 public immutable FUSER_UNIT;
    uint256 public nextPositionId = 1;
    uint256 public activePositionCount;
    uint256 public totalActiveCP;
    uint256 public totalEligibleCP;
    struct Position {
        uint256 principal;
        uint256 cp;
        uint64 createdAt;
        uint64 eligibleAt;
        uint64 unlockTime;
        uint32 durationDays;
        uint8 multiplier;
        bool active;
        bool eligible;
    }
    mapping(uint256 => Position) public positions;
    mapping(address => uint256) public principalLiability;
    mapping(address => uint256) public rewardLiability;
    mapping(address => uint256) public globalRewardIndex;
    mapping(address => uint256) public totalRewardsInjected;
    mapping(address => uint256) public totalRewardsClaimed;
    mapping(address => uint256) public totalRewardDustToMinter;
    // Rewards already crystallized to positions but not yet claimed.
    // Used to distinguish real holder liabilities from terminal rounding residue.
    mapping(address => uint256) public accruedRewardLiability;
    mapping(uint256 => mapping(address => uint256)) public positionRewardIndex;
    mapping(uint256 => mapping(address => uint256)) public accruedRewards;
    // A burned position can still own rewards crystallized before closure.
    mapping(uint256 => address) public finalRewardOwner;
    uint256[] private _coolingPositionIds;
    uint256 public eligibilityCursor;
    error WrongChain();
    error ZeroAddress();
    error InvalidAmountTier();
    error InvalidDurationTier();
    error PositionInactive();
    error PositionNotMature();
    error PositionAlreadyMature();
    error PositionStillCooling();
    error EligibilitySyncRequired();
    error NotPositionOwner();
    error UnsupportedRewardToken();
    error NoEligibleCP();
    error ZeroAmount();
    error ExactTransferRequired();
    error TransferLockedUntilMaturity();
    error SelfTransferForbidden();
    error Insolvent(address token, uint256 balance, uint256 liabilities);
    event PositionForged(
        uint256 indexed positionId,
        address indexed owner,
        uint256 principal,
        uint256 cp,
        uint256 durationDays,
        uint256 multiplier,
        uint256 eligibleAt,
        uint256 unlockTime
    );
    event PositionBecameEligible(uint256 indexed positionId, uint256 cp);
    event PositionCompleted(uint256 indexed positionId, address indexed owner, uint256 principal);
    event EmergencyExit(
        uint256 indexed positionId,
        address indexed owner,
        uint256 principal,
        uint256 returnedToOwner,
        uint256 distributedToEligibleCP,
        uint256 injectedToFUSEReserve,
        uint256 sentToMinter
    );
    event RewardInjected(
        address indexed rewardToken,
        address indexed injector,
        uint256 received,
        uint256 distributed,
        uint256 dustToMinter,
        uint256 eligibleCP
    );
    event RewardDustFinalized(address indexed rewardToken, uint256 amount);
    event RewardClaimed(
        uint256 indexed positionId,
        address indexed owner,
        address indexed rewardToken,
        uint256 amount
    );
    constructor(
        address fuserToken,
        address cvToken,
        address daiToken,
        address fusereserve,
        address minterAddress
    ) ERC721("FUSEReactor", "FREACTOR") {
        if (block.chainid != PULSECHAIN_ID) revert WrongChain();
        if (
            fuserToken == address(0) ||
            cvToken == address(0) ||
            daiToken == address(0) ||
            fusereserve == address(0) ||
            minterAddress == address(0)
        ) revert ZeroAddress();
        FUSER = IERC20(fuserToken);
        CV = IERC20(cvToken);
        DAI = IERC20(daiToken);
        FUSERESERVE = IFUSEReserveRewardSink(fusereserve);
        MINTER_ADDRESS = minterAddress;
        uint8 d = IERC20Metadata(fuserToken).decimals();
        require(d <= 18, "FUSEr decimals > 18");
        FUSER_DECIMALS = d;
        FUSER_UNIT = 10 ** uint256(d);
    }
    // =============================================================
    // CREATION
    // =============================================================
    /// @param wholeFuserAmount Must be 33, 369, 555 or 5,555.
    /// @param durationDays Must be 33, 369, 555 or 5,555.
    function forgePosition(
        uint256 wholeFuserAmount,
        uint256 durationDays
    ) external nonReentrant returns (uint256 positionId) {
        if (!_validAmount(wholeFuserAmount)) revert InvalidAmountTier();
        uint256 multiplier = _multiplierForDuration(durationDays);
        uint256 principal = wholeFuserAmount * FUSER_UNIT;
        uint256 cp = wholeFuserAmount * multiplier;
        _pullExact(FUSER, msg.sender, principal);
        positionId = nextPositionId++;
        uint64 nowTs = uint64(block.timestamp);
        positions[positionId] = Position({
            principal: principal,
            cp: cp,
            createdAt: nowTs,
            eligibleAt: uint64(block.timestamp + COOLING_PERIOD),
            unlockTime: uint64(block.timestamp + (durationDays * 1 days)),
            durationDays: uint32(durationDays),
            multiplier: uint8(multiplier),
            active: true,
            eligible: false
        });
        principalLiability[address(FUSER)] += principal;
        totalActiveCP += cp;
        activePositionCount += 1;
        _coolingPositionIds.push(positionId);
        _safeMint(msg.sender, positionId);
        Position storage r = positions[positionId];
        emit PositionForged(
            positionId,
            msg.sender,
            principal,
            cp,
            durationDays,
            multiplier,
            r.eligibleAt,
            r.unlockTime
        );
        _assertSolvent(address(FUSER));
    }
    // =============================================================
    // 24 HOUR ELIGIBILITY
    // =============================================================
    uint256 public constant MAX_SYNC_STEPS = 1_000;
    /// @notice Permissionless bounded synchronization for cooled positions.
    /// @dev Anyone may advance the cursor. A single call can process at most
    /// MAX_SYNC_STEPS entries, preventing an unbounded gas path.
    function syncEligibility(uint256 maxSteps) public {
        if (maxSteps == 0 || maxSteps > MAX_SYNC_STEPS) {
            maxSteps = MAX_SYNC_STEPS;
        }
        uint256 len = _coolingPositionIds.length;
        uint256 cursor = eligibilityCursor;
        uint256 steps;
        while (cursor < len && steps < maxSteps) {
            uint256 positionId = _coolingPositionIds[cursor];
            Position storage r = positions[positionId];
            // Entries are creation ordered. Once the first active position has
            // not finished cooling, no later active entry can be ready.
            if (r.active && !r.eligible && block.timestamp < r.eligibleAt) break;
            if (r.active && !r.eligible) {
                _activateEligibility(positionId, r);
            }
            unchecked {
                ++cursor;
                ++steps;
            }
        }
        eligibilityCursor = cursor;
    }
    function activatePosition(uint256 positionId) external {
        Position storage r = positions[positionId];
        if (!r.active) revert PositionInactive();
        if (r.eligible) return;
        if (block.timestamp < r.eligibleAt) revert PositionStillCooling();
        _activateEligibility(positionId, r);
    }
    function _activateEligibility(uint256 positionId, Position storage r) internal {
        r.eligible = true;
        totalEligibleCP += r.cp;
        // Eligibility begins at current indexes. No historical capture.
        positionRewardIndex[positionId][address(FUSER)] = globalRewardIndex[address(FUSER)];
        positionRewardIndex[positionId][address(CV)] = globalRewardIndex[address(CV)];
        positionRewardIndex[positionId][address(DAI)] = globalRewardIndex[address(DAI)];
        emit PositionBecameEligible(positionId, r.cp);
    }
    // =============================================================
    // GLOBAL MULTI-REWARD POOL
    // =============================================================
    /// @notice Inject FUSEr, CV or DAI and distribute by eligible CP.
    /// @dev FUSEReplace can use this for 369 CV OFFER fees and 2% DAI SALE fees.
    function injectReward(address rewardToken, uint256 amount) external nonReentrant {
        _requireSupportedReward(rewardToken);
        if (amount == 0) revert ZeroAmount();
        // Advance one bounded batch before fixing the CP denominator.
        // If additional ready entries remain, the defensive check below
        // reverts so callers can pre-sync them permissionlessly.
        syncEligibility(MAX_SYNC_STEPS);
        if (_hasReadyUnsyncedPosition()) revert EligibilitySyncRequired();
        if (totalEligibleCP == 0) revert NoEligibleCP();
        IERC20 token = IERC20(rewardToken);
        _pullExact(token, msg.sender, amount);
        _distributeHeldReward(rewardToken, amount, msg.sender);
        _assertSolvent(rewardToken);
    }
    function claimReward(
        uint256 positionId,
        address rewardToken
    ) public nonReentrant returns (uint256 amount) {
        _requireSupportedReward(rewardToken);
        address beneficiary = _rewardOwner(positionId);
        if (beneficiary == address(0) || beneficiary != msg.sender) {
            revert NotPositionOwner();
        }
        Position storage r = positions[positionId];
        if (r.active && !r.eligible && block.timestamp >= r.eligibleAt) {
            _activateEligibility(positionId, r);
        }
        _accrue(positionId, rewardToken);
        amount = accruedRewards[positionId][rewardToken];
        if (amount == 0) return 0;
        accruedRewards[positionId][rewardToken] = 0;
        rewardLiability[rewardToken] -= amount;
        accruedRewardLiability[rewardToken] -= amount;
        totalRewardsClaimed[rewardToken] += amount;
        IERC20(rewardToken).safeTransfer(msg.sender, amount);
        emit RewardClaimed(positionId, msg.sender, rewardToken, amount);
        _assertSolvent(rewardToken);
    }
    /// @notice Convenience claim. Separate internal claims avoid nested
    /// nonReentrant external calls.
    function claimAllRewards(
        uint256 positionId
    ) external nonReentrant returns (
        uint256 fuserAmount,
        uint256 cvAmount,
        uint256 daiAmount
    ) {
        address beneficiary = _rewardOwner(positionId);
        if (beneficiary == address(0) || beneficiary != msg.sender) {
            revert NotPositionOwner();
        }
        Position storage r = positions[positionId];
        if (r.active && !r.eligible && block.timestamp >= r.eligibleAt) {
            _activateEligibility(positionId, r);
        }
        fuserAmount = _claimOne(positionId, address(FUSER), msg.sender);
        cvAmount = _claimOne(positionId, address(CV), msg.sender);
        daiAmount = _claimOne(positionId, address(DAI), msg.sender);
    }
    function _claimOne(
        uint256 positionId,
        address rewardToken,
        address beneficiary
    ) internal returns (uint256 amount) {
        _accrue(positionId, rewardToken);
        amount = accruedRewards[positionId][rewardToken];
        if (amount == 0) return 0;
        accruedRewards[positionId][rewardToken] = 0;
        rewardLiability[rewardToken] -= amount;
        accruedRewardLiability[rewardToken] -= amount;
        totalRewardsClaimed[rewardToken] += amount;
        IERC20(rewardToken).safeTransfer(beneficiary, amount);
        emit RewardClaimed(positionId, beneficiary, rewardToken, amount);
        _assertSolvent(rewardToken);
    }
    function pendingReward(
        uint256 positionId,
        address rewardToken
    ) external view returns (uint256) {
        _requireSupportedReward(rewardToken);
        Position storage r = positions[positionId];
        uint256 pending = accruedRewards[positionId][rewardToken];
        if (!r.active || !r.eligible) return pending;
        uint256 delta =
            globalRewardIndex[rewardToken] -
            positionRewardIndex[positionId][rewardToken];
        return pending + ((r.cp * delta) / INDEX_PRECISION);
    }
    function _accrueAll(uint256 positionId) internal {
        _accrue(positionId, address(FUSER));
        _accrue(positionId, address(CV));
        _accrue(positionId, address(DAI));
    }
    function _accrue(uint256 positionId, address rewardToken) internal {
        Position storage r = positions[positionId];
        if (!r.eligible) return;
        uint256 currentIndex = globalRewardIndex[rewardToken];
        uint256 checkpoint = positionRewardIndex[positionId][rewardToken];
        if (currentIndex > checkpoint) {
            uint256 earned =
                (r.cp * (currentIndex - checkpoint)) /
                INDEX_PRECISION;
            if (earned != 0) {
                accruedRewards[positionId][rewardToken] += earned;
                accruedRewardLiability[rewardToken] += earned;
            }
            positionRewardIndex[positionId][rewardToken] = currentIndex;
        }
    }
    /// @dev Amount is already held by this contract and not principal.
    function _distributeHeldReward(
        address rewardToken,
        uint256 amount,
        address injector
    ) internal {
        if (totalEligibleCP == 0) revert NoEligibleCP();
        // IMPORTANT: reserve the entire injected amount as reward liability.
        // Never transfer per-distribution rounding residue to MINTer here.
        // A fractional index that looks like "dust" in one distribution can
        // combine with later distributions and become legitimately claimable.
        // Terminal dust is finalized only when totalEligibleCP reaches zero,
        // after every departing eligible position has crystallized its rewards.
        uint256 deltaIndex =
            (amount * INDEX_PRECISION) /
            totalEligibleCP;
        globalRewardIndex[rewardToken] += deltaIndex;
        rewardLiability[rewardToken] += amount;
        totalRewardsInjected[rewardToken] += amount;
        emit RewardInjected(
            rewardToken,
            injector,
            amount,
            amount,
            0,
            totalEligibleCP
        );
    }
    // =============================================================
    // MATURITY AND 100% PRINCIPAL REDEMPTION
    // =============================================================
    function completePosition(uint256 positionId) external nonReentrant {
        Position storage r = positions[positionId];
        if (!r.active) revert PositionInactive();
        address owner = ownerOf(positionId);
        if (owner != msg.sender) revert NotPositionOwner();
        if (block.timestamp < r.unlockTime) revert PositionNotMature();
        if (!r.eligible && block.timestamp >= r.eligibleAt) {
            _activateEligibility(positionId, r);
        }
        _accrueAll(positionId);
        uint256 principal = r.principal;
        _removeFromActiveAccounting(r);
        _finalizeRoundingDustIfNoEligibleCP();
        finalRewardOwner[positionId] = owner;
        principalLiability[address(FUSER)] -= principal;
        _burn(positionId);
        FUSER.safeTransfer(owner, principal);
        emit PositionCompleted(positionId, owner, principal);
        _assertSolvent(address(FUSER));
    }
    // =============================================================
    // EARLY EXIT 50 / 30 / 15 / 5
    // =============================================================
    function emergencyExit(uint256 positionId) external nonReentrant {
        // Materialize every position whose 24h cooling period has already ended
        // before any emergency-exit distribution fixes its CP denominator.
        syncEligibility(MAX_SYNC_STEPS);
        if (_hasReadyUnsyncedPosition()) revert EligibilitySyncRequired();
        Position storage r = positions[positionId];
        if (!r.active) revert PositionInactive();
        address owner = ownerOf(positionId);
        if (owner != msg.sender) revert NotPositionOwner();
        if (block.timestamp >= r.unlockTime) revert PositionAlreadyMature();
        // Earn through the exit instant if cooling has completed.
        if (!r.eligible && block.timestamp >= r.eligibleAt) {
            _activateEligibility(positionId, r);
        }
        _accrueAll(positionId);
        uint256 principal = r.principal;
        // Remove first. The exiting position cannot receive its own penalty.
        _removeFromActiveAccounting(r);
        _finalizeRoundingDustIfNoEligibleCP();
        finalRewardOwner[positionId] = owner;
        principalLiability[address(FUSER)] -= principal;
        _burn(positionId);
        uint256 ownerAmount = (principal * 50) / 100;
        uint256 cpAmount = (principal * 30) / 100;
        uint256 fusereserveAmount = (principal * 15) / 100;
        // MINTer receives 5% plus all percentage rounding residue.
        uint256 minterAmount =
            principal -
            ownerAmount -
            cpAmount -
            fusereserveAmount;
        // 30% goes only to remaining eligible FUSEreactor CP.
        if (cpAmount != 0) {
            if (totalEligibleCP == 0) {
                minterAmount += cpAmount;
                cpAmount = 0;
            } else {
                _distributeHeldReward(address(FUSER), cpAmount, address(this));
            }
        }
        // 15% is injected into FUSEReserve's accounting-aware reward pool.
        // FUSEr must be registered/supported there before production use.
        if (fusereserveAmount != 0) {
            FUSER.forceApprove(address(FUSERESERVE), fusereserveAmount);
            FUSERESERVE.injectReward(address(FUSER), fusereserveAmount);
            FUSER.forceApprove(address(FUSERESERVE), 0);
        }
        if (minterAmount != 0) {
            FUSER.safeTransfer(MINTER_ADDRESS, minterAmount);
        }
        if (ownerAmount != 0) {
            FUSER.safeTransfer(owner, ownerAmount);
        }
        emit EmergencyExit(
            positionId,
            owner,
            principal,
            ownerAmount,
            cpAmount,
            fusereserveAmount,
            minterAmount
        );
        _assertSolvent(address(FUSER));
    }
    // =============================================================
    // TRANSFERABILITY
    // =============================================================
    /// @dev ERC721 transfer is locked until maturity. Mature transfers do not
    /// close the position or remove CP. Historical unclaimed rewards stay with
    /// the economic position and therefore follow the NFT.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            if (from == to) revert SelfTransferForbidden();
            Position storage r = positions[tokenId];
            if (!r.active) revert PositionInactive();
            if (block.timestamp < r.unlockTime) {
                revert TransferLockedUntilMaturity();
            }
            _accrueAll(tokenId);
        }
        return super._update(to, tokenId, auth);
    }
    // =============================================================
    // VIEWS
    // =============================================================
    function positionStatus(
        uint256 positionId
    ) external view returns (
        bool active,
        bool cooling,
        bool earning,
        bool matured,
        bool transferable,
        uint256 principal,
        uint256 cp,
        uint256 eligibleAt,
        uint256 unlockTime
    ) {
        Position storage r = positions[positionId];
        active = r.active;
        principal = r.principal;
        cp = r.cp;
        eligibleAt = r.eligibleAt;
        unlockTime = r.unlockTime;
        if (active) {
            cooling = block.timestamp < r.eligibleAt;
            earning = block.timestamp >= r.eligibleAt;
            matured = block.timestamp >= r.unlockTime;
            transferable = matured;
        }
    }
    function rewardOwner(uint256 positionId) external view returns (address) {
        return _rewardOwner(positionId);
    }
    function supportedRewardToken(address token) public view returns (bool) {
        return
            token == address(FUSER) ||
            token == address(CV) ||
            token == address(DAI);
    }
    function solvencyOf(
        address token
    ) external view returns (
        uint256 balance,
        uint256 principal,
        uint256 rewards,
        uint256 required,
        bool solvent
    ) {
        balance = IERC20(token).balanceOf(address(this));
        principal = principalLiability[token];
        rewards = rewardLiability[token];
        required = principal + rewards;
        solvent = balance >= required;
    }
    function coolingPositionCount() external view returns (uint256) {
        return _coolingPositionIds.length;
    }
    function coolingPositionIdAt(uint256 index) external view returns (uint256) {
        return _coolingPositionIds[index];
    }
    // =============================================================
    // INTERNAL HELPERS
    // =============================================================
    function _removeFromActiveAccounting(Position storage r) internal {
        if (r.eligible) {
            totalEligibleCP -= r.cp;
            r.eligible = false;
        }
        totalActiveCP -= r.cp;
        activePositionCount -= 1;
        r.active = false;
    }
    /// @dev Once no eligible CP remains, every reward entitlement from the
    /// completed reward era has been crystallized by each position as it left
    /// eligibility. Any reward liability above accruedRewardLiability can no
    /// longer belong to a holder and is therefore terminal integer-rounding dust.
    /// It is safe to release only at this zero-eligible-CP boundary.
    function _finalizeRoundingDustIfNoEligibleCP() internal {
        if (totalEligibleCP != 0) return;
        _finalizeRoundingDust(address(FUSER));
        _finalizeRoundingDust(address(CV));
        _finalizeRoundingDust(address(DAI));
    }
    function _finalizeRoundingDust(address rewardToken) internal {
        uint256 liability = rewardLiability[rewardToken];
        uint256 crystallized = accruedRewardLiability[rewardToken];
        if (liability <= crystallized) return;
        uint256 dust = liability - crystallized;
        rewardLiability[rewardToken] = crystallized;
        totalRewardDustToMinter[rewardToken] += dust;
        IERC20(rewardToken).safeTransfer(MINTER_ADDRESS, dust);
        emit RewardDustFinalized(rewardToken, dust);
        _assertSolvent(rewardToken);
    }
    function _rewardOwner(uint256 positionId) internal view returns (address) {
        address current = _ownerOf(positionId);
        if (current != address(0)) return current;
        return finalRewardOwner[positionId];
    }
    function _pullExact(
        IERC20 token,
        address from,
        uint256 amount
    ) internal {
        uint256 beforeBal = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - beforeBal;
        if (received != amount) revert ExactTransferRequired();
    }
    function _assertSolvent(address token) internal view {
        uint256 liabilities =
            principalLiability[token] +
            rewardLiability[token];
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < liabilities) {
            revert Insolvent(token, balance, liabilities);
        }
    }
    /// @notice Returns true when at least one cooled position is ready
    ///         but has not yet been incorporated into totalEligibleCP.
    function eligibilitySyncRequired() external view returns (bool) {
        return _hasReadyUnsyncedPosition();
    }
    /// @notice Frontend/marketplace synchronization state.
    function eligibilitySyncState()
        external
        view
        returns (
            uint256 cursor,
            uint256 queueLength,
            bool syncRequired
        )
    {
        cursor = eligibilityCursor;
        queueLength = _coolingPositionIds.length;
        syncRequired = _hasReadyUnsyncedPosition();
    }
    function _hasReadyUnsyncedPosition() internal view returns (bool) {
        uint256 cursor = eligibilityCursor;
        if (cursor >= _coolingPositionIds.length) return false;
        Position storage r = positions[_coolingPositionIds[cursor]];
        return r.active && !r.eligible && block.timestamp >= r.eligibleAt;
    }
    function _validAmount(uint256 amount) internal pure returns (bool) {
        return
            amount == 33 ||
            amount == 369 ||
            amount == 555 ||
            amount == 5_555;
    }
    function _multiplierForDuration(
        uint256 durationDays
    ) internal pure returns (uint256) {
        if (durationDays == 33) return 1;
        if (durationDays == 369) return 2;
        if (durationDays == 555) return 3;
        if (durationDays == 5_555) return 4;
        revert InvalidDurationTier();
    }
    function _requireSupportedReward(address token) internal view {
        if (!supportedRewardToken(token)) {
            revert UnsupportedRewardToken();
        }
    }
}
