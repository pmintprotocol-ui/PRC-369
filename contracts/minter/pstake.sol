// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPCOINMining {
    function mine(uint256 pdaiAmount, uint256 referralCode, uint256 minDAICOINOut) external;
    function claim(uint256 positionId) external;
    function getPositionCount(address miner) external view returns (uint256);
    function getPosition(address miner, uint256 id)
        external view returns (uint256 pdaiToReturn, uint256 pcoinReward, uint256 unlockTime, bool claimed);
    function claimDividend() external;
    function pendingDividend(address account) external view returns (uint256);
    function miningFinished() external view returns (bool);
    function outstandingPCOIN() external view returns (uint256);
    function totalOutstandingMinerPDAI() external view returns (uint256);
}

/// @author MINTer
contract pSTAKE is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant PENALTY_BPS = 5_000;
    uint256 public constant REWARD_COOLDOWN = 1 days;
    uint256 public constant ACTIVATION_PDAI = 369 ether;
    uint256 public constant ACC = 1e18;
    uint256 private constant NOT_ACTIVATED = type(uint256).max;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    IERC20 public immutable pcoin;
    IERC20 public immutable pdai;
    IPCOINMining public immutable mining;

    uint256 public nextStakeId = 1;
    uint256 public totalLockedPCOIN;
    uint256 public totalPS;
    uint256 public eligiblePS;
    uint256 public totalFinalEligiblePS;
    uint256 public forfeitedFinalPS;
    uint256 public pcoinPerPSStored;
    uint256 public pdaiPerPCOINStored;
    uint256 public totalDividendCredit;
    uint256 public dividendCreditTracker;

    uint256 public miningPDAIReserve;
    uint256 public finalPDAIPool;
    uint256 public finalPSAtSnapshot;
    uint256 public unallocatedPCOINRewards;
    bool public finalDistributionActivated;
    uint256 public totalMiningPositionsCreated;
    uint256 public totalMiningPositionsClaimed;

    struct Stake {
        address owner;
        uint128 amount;
        uint128 ps;
        uint64 startTime;
        uint64 unlockTime;
        uint32 durationDays;
        uint16 amountTier;
        uint16 durationTier;
        uint256 dividendDebt;
        uint256 rewardDebt;
        bool principalClaimed;
        bool finalClaimed;
        bool finalEligible;
    }

    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) private userStakeIds;
    mapping(uint256 => uint256) public miningPositionForStake;
    mapping(uint256 => bool) public miningPositionRegistered;
    mapping(uint256 => bool) public miningPositionClaimed;

    uint256 public loyaltyPoolBalance;
    uint256 public totalEarlyExitBurned;
    uint256 public totalLoyaltyDistributed;
    uint256 public totalFinalPDAIDistributed;

    event StakeCreated(uint256 indexed stakeId, address indexed user, uint256 amount,
        uint256 durationDays, uint256 ps, uint256 miningPositionId);
    event StakeMatured(uint256 indexed stakeId, address indexed user, uint256 principal);
    event StakeExitedEarly(uint256 indexed stakeId, address indexed user,
        uint256 returnedAmount, uint256 burnedAmount, uint256 loyaltyAmount);
    event MiningPositionClaimed(uint256 indexed miningPositionId, uint256 pcoinReward, uint256 pdaiRefund);
    event MiningPDAIReinvested(uint256 amount, uint256 miningPositionId);
    event MiningDividendSynced(uint256 amount);
    event LoyaltyClaimed(uint256 indexed stakeId, address indexed user, uint256 amount);
    event FinalDistributionActivated(uint256 pdaiAmount, uint256 totalPS);
    event FinalPDAIClaimed(uint256 indexed stakeId, address indexed user, uint256 amount);

    error InvalidAddress();
    error InvalidAmountTier();
    error InvalidDurationTier();
    error InvalidStake();
    error NotStakeOwner();
    error StakeNotMatured();
    error StakeAlreadyClosed();
    error NothingToClaim();
    error MiningAlreadyFinished();
    error MiningNotFinished();
    error MiningPositionsOutstanding();
    error InsufficientPool();
    error FinalDistributionAlreadyActivated();

    constructor(address pcoin_, address pdai_, address mining_) {
        if (pcoin_ == address(0) || pdai_ == address(0) || mining_ == address(0)) revert InvalidAddress();
        pcoin = IERC20(pcoin_);
        pdai = IERC20(pdai_);
        mining = IPCOINMining(mining_);
    }

    function stake(uint256 amount, uint256 durationDays, uint256 minDAICOINOut)
        external nonReentrant returns (uint256 stakeId)
    {
        if (finalDistributionActivated || mining.miningFinished()) revert MiningAlreadyFinished();
        uint16 aTier = _amountTier(amount);
        uint16 dTier = _durationTier(durationDays);
        uint256 ps = amount * durationDays * _multiplier(dTier) / BPS;
        require(ps > 0 && ps <= type(uint128).max && amount <= type(uint128).max, "PS overflow");

        _syncDividendAccumulator();
        pcoin.safeTransferFrom(msg.sender, address(this), amount);
        pdai.safeTransferFrom(msg.sender, address(this), ACTIVATION_PDAI);

        stakeId = nextStakeId++;
        uint256 unlock = block.timestamp + durationDays * 1 days;
        stakes[stakeId] = Stake({
            owner: msg.sender,
            amount: uint128(amount),
            ps: uint128(ps),
            startTime: uint64(block.timestamp),
            unlockTime: uint64(unlock),
            durationDays: uint32(durationDays),
            amountTier: aTier,
            durationTier: dTier,
            dividendDebt: pdaiPerPCOINStored,
            rewardDebt: NOT_ACTIVATED,
            principalClaimed: false,
            finalClaimed: false,
            finalEligible: false
        });
        userStakeIds[msg.sender].push(stakeId);
        totalLockedPCOIN += amount;
        totalPS += ps;

        pdai.forceApprove(address(mining), ACTIVATION_PDAI);
        uint256 beforeCount = mining.getPositionCount(address(this));
        mining.mine(ACTIVATION_PDAI, 0, minDAICOINOut);
        pdai.forceApprove(address(mining), 0);
        uint256 afterCount = mining.getPositionCount(address(this));
        require(afterCount == beforeCount + 1, "mining position mismatch");
        miningPositionForStake[stakeId] = afterCount - 1;
        miningPositionRegistered[afterCount - 1] = true;
        totalMiningPositionsCreated += 1;

        emit StakeCreated(stakeId, msg.sender, amount, durationDays, ps, afterCount - 1);
    }

    // Permissionless: the mining contract sends its PCOIN reward and refundable
    // pDAI to this contract. PCOIN joins the PS-weighted loyalty pool.
    function claimMiningPosition(uint256 miningPositionId) external nonReentrant {
        if (!miningPositionRegistered[miningPositionId] || miningPositionClaimed[miningPositionId]) revert InvalidStake();
        (uint256 refund, uint256 reward, uint256 unlock, bool claimed) =
            mining.getPosition(address(this), miningPositionId);
        require(!claimed && block.timestamp >= unlock, "mining position locked");

        uint256 beforeDAI = pdai.balanceOf(address(this));
        uint256 beforePCOIN = pcoin.balanceOf(address(this));
        mining.claim(miningPositionId);
        uint256 receivedDAI = pdai.balanceOf(address(this)) - beforeDAI;
        uint256 receivedPCOIN = pcoin.balanceOf(address(this)) - beforePCOIN;
        require(receivedDAI == refund && receivedPCOIN == reward, "claim accounting mismatch");

        miningPositionClaimed[miningPositionId] = true;
        totalMiningPositionsClaimed += 1;
        miningPDAIReserve += receivedDAI;
        if (receivedPCOIN != 0) {
            if (eligiblePS == 0) unallocatedPCOINRewards += receivedPCOIN;
            else {
                loyaltyPoolBalance += receivedPCOIN;
                pcoinPerPSStored += receivedPCOIN * ACC / eligiblePS;
            }
        }
        emit MiningPositionClaimed(miningPositionId, receivedPCOIN, receivedDAI);
    }

    // Recycles refundable pDAI into another mining position while cycles remain.
    function reinvestMiningPDAI(uint256 amount, uint256 minDAICOINOut) external nonReentrant {
        if (mining.miningFinished()) revert MiningAlreadyFinished();
        require(amount != 0 && amount <= miningPDAIReserve, "invalid reinvest amount");
        miningPDAIReserve -= amount;
        pdai.forceApprove(address(mining), amount);
        uint256 beforeCount = mining.getPositionCount(address(this));
        mining.mine(amount, 0, minDAICOINOut);
        pdai.forceApprove(address(mining), 0);
        uint256 afterCount = mining.getPositionCount(address(this));
        require(afterCount == beforeCount + 1, "mining position mismatch");
        miningPositionRegistered[afterCount - 1] = true;
        totalMiningPositionsCreated += 1;
        emit MiningPDAIReinvested(amount, afterCount - 1);
    }

    // Virtual dividend accounting protects existing lockers from dilution.
    function syncMiningDividends() external nonReentrant {
        _syncDividendAccumulator();
        uint256 owed = mining.pendingDividend(address(this));
        if (owed < 5 ether) return;
        uint256 beforeBalance = pdai.balanceOf(address(this));
        try mining.claimDividend() {
            uint256 received = pdai.balanceOf(address(this)) - beforeBalance;
            if (received != 0) {
                totalDividendCredit += received;
                dividendCreditTracker = 0;
                emit MiningDividendSynced(received);
            }
        } catch {}
    }

    function claimDividends(uint256 stakeId) external nonReentrant {
        Stake storage s = stakes[stakeId];
        if (s.owner != msg.sender) revert NotStakeOwner();
        if (s.principalClaimed) revert StakeAlreadyClosed();
        _syncDividendAccumulator();
        uint256 owed = uint256(s.amount) * (pdaiPerPCOINStored - s.dividendDebt) / ACC;
        if (owed == 0 || owed > totalDividendCredit) revert NothingToClaim();
        s.dividendDebt = pdaiPerPCOINStored;
        totalDividendCredit -= owed;
        pdai.safeTransfer(msg.sender, owed);
    }

    function claimLoyalty(uint256 stakeId) external nonReentrant {
        Stake storage s = stakes[stakeId];
        if (s.owner != msg.sender) revert NotStakeOwner();
        if (s.principalClaimed) revert StakeAlreadyClosed();
        _activateIfReady(s);
        if (s.rewardDebt == NOT_ACTIVATED) revert NothingToClaim();
        uint256 owed = uint256(s.ps) * (pcoinPerPSStored - s.rewardDebt) / ACC;
        if (owed == 0 || owed > loyaltyPoolBalance) revert NothingToClaim();
        s.rewardDebt = pcoinPerPSStored;
        loyaltyPoolBalance -= owed;
        totalLoyaltyDistributed += owed;
        pcoin.safeTransfer(msg.sender, owed);
        emit LoyaltyClaimed(stakeId, msg.sender, owed);
    }

    function endStake(uint256 stakeId) external nonReentrant {
        Stake storage s = stakes[stakeId];
        if (s.owner != msg.sender) revert NotStakeOwner();
        if (s.principalClaimed) revert StakeAlreadyClosed();
        if (block.timestamp < s.unlockTime) revert StakeNotMatured();
        _syncDividendAccumulator();
        _activateIfReady(s);
        _settleStake(s);
        s.principalClaimed = true;
        totalLockedPCOIN -= s.amount;
        totalPS -= s.ps;
        if (s.rewardDebt != NOT_ACTIVATED) eligiblePS -= s.ps;
        pcoin.safeTransfer(msg.sender, s.amount);
        emit StakeMatured(stakeId, msg.sender, s.amount);
    }

    function emergencyExit(uint256 stakeId) external nonReentrant {
        Stake storage s = stakes[stakeId];
        if (s.owner != msg.sender) revert NotStakeOwner();
        if (s.principalClaimed) revert StakeAlreadyClosed();
        require(block.timestamp < s.unlockTime, "already matured");
        _syncDividendAccumulator();
        _activateIfReady(s);
        _settleStake(s);

        s.principalClaimed = true;
        totalLockedPCOIN -= s.amount;
        totalPS -= s.ps;
        if (s.rewardDebt != NOT_ACTIVATED) {
            eligiblePS -= s.ps;
            if (s.finalEligible && !finalDistributionActivated) {
                forfeitedFinalPS += s.ps;
                s.finalEligible = false;
            }
        }

        uint256 penalty = uint256(s.amount) * PENALTY_BPS / BPS;
        uint256 returned = uint256(s.amount) - penalty;
        uint256 burned = penalty / 2;
        uint256 loyalty = penalty - burned;
        if (loyalty != 0 && eligiblePS != 0) {
            loyaltyPoolBalance += loyalty;
            pcoinPerPSStored += loyalty * ACC / eligiblePS;
        } else if (loyalty != 0) {
            burned += loyalty;
            loyalty = 0;
        }
        totalEarlyExitBurned += burned;
        if (burned != 0) pcoin.safeTransfer(DEAD, burned);
        if (returned != 0) pcoin.safeTransfer(msg.sender, returned);
        emit StakeExitedEarly(stakeId, msg.sender, returned, burned, loyalty);
    }

    // Final distribution waits for every mining position (including recycled
    // positions) to be claimed and all mining principal/reward obligations to clear.
    function activateFinalDistribution() external nonReentrant {
        if (finalDistributionActivated) revert FinalDistributionAlreadyActivated();
        if (!mining.miningFinished()) revert MiningNotFinished();
        if (mining.outstandingPCOIN() != 0 || mining.totalOutstandingMinerPDAI() != 0) {
            revert MiningPositionsOutstanding();
        }
        if (totalMiningPositionsClaimed != totalMiningPositionsCreated) {
            revert MiningPositionsOutstanding();
        }
        if (mining.getPositionCount(address(this)) != totalMiningPositionsCreated) {
            revert MiningPositionsOutstanding();
        }
        finalDistributionActivated = true;
        finalPSAtSnapshot = totalFinalEligiblePS - forfeitedFinalPS;
        finalPDAIPool = miningPDAIReserve;
        miningPDAIReserve = 0;
        emit FinalDistributionActivated(finalPDAIPool, finalPSAtSnapshot);
    }

    function claimFinalPDAI(uint256 stakeId) external nonReentrant {
        if (!finalDistributionActivated) revert MiningNotFinished();
        Stake storage s = stakes[stakeId];
        if (s.owner != msg.sender) revert NotStakeOwner();
        if (s.finalClaimed || !s.finalEligible || finalPSAtSnapshot == 0) revert NothingToClaim();
        uint256 amount = uint256(s.ps) * finalPDAIPool / finalPSAtSnapshot;
        if (amount == 0) revert NothingToClaim();
        s.finalClaimed = true;
        totalFinalPDAIDistributed += amount;
        pdai.safeTransfer(msg.sender, amount);
        emit FinalPDAIClaimed(stakeId, msg.sender, amount);
    }

    function _syncDividendAccumulator() internal {
        if (totalLockedPCOIN == 0) return;
        uint256 pending = mining.pendingDividend(address(this));
        if (pending > dividendCreditTracker) {
            uint256 delta = pending - dividendCreditTracker;
            pdaiPerPCOINStored += delta * ACC / totalLockedPCOIN;
            dividendCreditTracker = pending;
        }
    }

    function _activateIfReady(Stake storage s) internal {
        if (s.rewardDebt != NOT_ACTIVATED || block.timestamp < uint256(s.startTime) + REWARD_COOLDOWN) return;
        s.rewardDebt = pcoinPerPSStored;
        s.finalEligible = true;
        eligiblePS += s.ps;
        totalFinalEligiblePS += s.ps;
        if (unallocatedPCOINRewards != 0) {
            uint256 queued = unallocatedPCOINRewards;
            unallocatedPCOINRewards = 0;
            loyaltyPoolBalance += queued;
            pcoinPerPSStored += queued * ACC / eligiblePS;
        }
    }

    function _settleStake(Stake storage s) internal {
        if (s.rewardDebt != NOT_ACTIVATED) {
            uint256 reward = uint256(s.ps) * (pcoinPerPSStored - s.rewardDebt) / ACC;
            if (reward > loyaltyPoolBalance) revert InsufficientPool();
            if (reward != 0) {
                s.rewardDebt = pcoinPerPSStored;
                loyaltyPoolBalance -= reward;
                totalLoyaltyDistributed += reward;
                pcoin.safeTransfer(msg.sender, reward);
            }
        }

        uint256 dividend = uint256(s.amount) * (pdaiPerPCOINStored - s.dividendDebt) / ACC;
        if (dividend > totalDividendCredit) revert InsufficientPool();
        if (dividend != 0) {
            s.dividendDebt = pdaiPerPCOINStored;
            totalDividendCredit -= dividend;
            pdai.safeTransfer(msg.sender, dividend);
        }
    }

    function getUserStakeIds(address user) external view returns (uint256[] memory) {
        return userStakeIds[user];
    }

    function previewPS(uint256 amount, uint256 durationDays) external pure returns (uint256) {
        require(_validAmount(amount), "invalid amount");
        return amount * durationDays * _multiplier(_durationTier(durationDays)) / BPS;
    }

    function miningPositionCount() external view returns (uint256) {
        return mining.getPositionCount(address(this));
    }

    function miningFinished() external view returns (bool) {
        return mining.miningFinished();
    }

    function _validAmount(uint256 amount) internal pure returns (bool) {
        return amount == 1_000 ether || amount == 2_000 ether || amount == 3_000 ether ||
            amount == 4_000 ether || amount == 5_000 ether || amount == 25_000 ether ||
            amount == 50_000 ether || amount == 100_000 ether;
    }

    function _amountTier(uint256 amount) internal pure returns (uint16) {
        if (amount == 1_000 ether) return 0;
        if (amount == 2_000 ether) return 1;
        if (amount == 3_000 ether) return 2;
        if (amount == 4_000 ether) return 3;
        if (amount == 5_000 ether) return 4;
        if (amount == 25_000 ether) return 5;
        if (amount == 50_000 ether) return 6;
        if (amount == 100_000 ether) return 7;
        revert InvalidAmountTier();
    }

    function _durationTier(uint256 days_) internal pure returns (uint16) {
        if (days_ == 60) return 0;
        if (days_ == 90) return 1;
        if (days_ == 120) return 2;
        if (days_ == 180) return 3;
        if (days_ == 360) return 4;
        if (days_ == 555) return 5;
        if (days_ == 5_555) return 6;
        revert InvalidDurationTier();
    }

    function _multiplier(uint16 tier) internal pure returns (uint256) {
        if (tier == 0) return 10_000;
        if (tier == 1) return 11_500;
        if (tier == 2) return 13_500;
        if (tier == 3) return 17_500;
        if (tier == 4) return 25_000;
        if (tier == 5) return 35_000;
        return 100_000;
    }
}
