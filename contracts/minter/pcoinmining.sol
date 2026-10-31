// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPCOINToken is IERC20 {
    function registerPair(address pair) external;
    function notifyDividend(uint256 amount) external;
    function consumeDividend(address account) external returns (uint256);
    function pendingDividend(address account) external view returns (uint256);
    function burn(uint256 amount) external;
    function totalSellFeesCollected() external view returns (uint256);
}

interface IV2RouterPCOIN {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path,
        address to, uint256 deadline) external returns (uint256[] memory amounts);
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired,
        uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)
        external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IV2PairPCOIN {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
}

/// @title PCOINMining
/// @author MINTer
/// @notice Fork of PMINTMining.
/// @dev PulseChain; router must be a verified PulseX V2 router.
/// @dev All pDAI deposits retain 90% refundable pDAI, 3% pDAI dividends,
///      1% pDAI referrals, 1% pDAI treasury. 3% + 2% swap to DAICOIN.
contract PCOINMining is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant INITIAL_RATE = 3;
    uint256 public constant LOCK_DURATION = 24 hours;
    uint256 public constant MAX_CYCLES = 32;
    uint256 public constant INITIAL_CYCLE_EMISSION = 10_500_000 ether;
    uint256 public constant MINER_SHARE = 85;
    uint256 public constant LP_SHARE = 15;
    uint256 public constant SEED_ALLOCATION = 100_000 ether;
    uint256 public constant LP_BPS = 300;
    uint256 public constant DIVIDEND_BPS = 300;
    uint256 public constant BUYBACK_BPS = 200;
    uint256 public constant REFERRAL_BPS = 100;
    uint256 public constant TREASURY_BPS = 100;
    uint256 public constant MIN_DIVIDEND_CLAIM = 5 ether;
    uint256 public constant MIN_BUYBACK = 100 ether;
    uint256 public constant FLUSH_COOLDOWN = 10 minutes;
    uint256 public constant MAX_FLUSH_AMOUNT = 20_000 ether;

    IERC20 public immutable pdai;
    IERC20 public immutable daicoin;
    IERC20 public immutable mintcoin;
    IV2RouterPCOIN public immutable router;
    address public immutable treasury;
    IPCOINToken public pcoin;
    address public pairDAICOIN;
    address public pairPLS;
    bool public seedAllocated;
    bool public miningFinished;

    uint256 public currentCycle = 1;
    uint256 public currentRate = INITIAL_RATE;
    uint256 public cycleRemainingMiners = INITIAL_CYCLE_EMISSION * MINER_SHARE / 100;
    uint256 public cycleRemainingLP = INITIAL_CYCLE_EMISSION * LP_SHARE / 100;
    uint256 public outstandingPCOIN;
    uint256 public totalOutstandingMinerPDAI;
    uint256 public dividendReserve;
    uint256 public accumulatedDAICOINForLP;
    uint256 public buybackAccumulatorDAICOIN;
    uint256 public lastFlushTime;
    uint256 public lastFlushBlock;
    uint256 public sellFeesProcessed;
    uint256 private nextCode = 1;

    mapping(uint256 => address) public codeToWallet;
    mapping(address => uint256) public walletToCode;
    mapping(address => address) public referrer;
    mapping(address => bool) public hasMined;

    struct MinerPosition {
        uint256 pdaiToReturn;
        uint256 pcoinReward;
        uint256 unlockTime;
        bool claimed;
    }
    mapping(address => MinerPosition[]) public positions;

    event Mined(address indexed miner, uint256 indexed positionId, uint256 pdaiIn,
        uint256 daicoinBought, uint256 pcoinOut, uint256 unlock);
    event Claimed(address indexed miner, uint256 indexed positionId, uint256 pdaiOut, uint256 pcoinOut);
    event CycleAdvanced(uint256 cycle, uint256 rate);
    event LiquidityAdded(uint256 daicoinIn, uint256 pcoinIn, uint256 lpTokens);
    event BuybackExecuted(uint256 daicoinIn, uint256 mintcoinSentToDead);
    event SurplusPCOINBurnExecuted(uint256 daicoinIn, uint256 pcoinBurned);
    event MiningFinished(uint256 finalCycle);
    event SellFeeBurnExecuted(uint256 pcoinIn, uint256 daicoinIntermediate, uint256 mintcoinSentToDead);
    event DividendClaimed(address indexed account, uint256 amount);
    event CodeGenerated(address indexed wallet, uint256 code);

    constructor(address _pdai, address _daicoin, address _mintcoin, address _router, address _treasury) Ownable(msg.sender) {
        require(_pdai != address(0) && _daicoin != address(0) && _mintcoin != address(0)
            && _router != address(0) && _treasury != address(0), "zero address");
        require(_pdai != _daicoin && _daicoin != _mintcoin && _pdai != _mintcoin, "same assets");
        pdai = IERC20(_pdai);
        daicoin = IERC20(_daicoin);
        mintcoin = IERC20(_mintcoin);
        router = IV2RouterPCOIN(_router);
        treasury = _treasury;
    }

    function setTokenAddress(address token) external onlyOwner {
        require(address(pcoin) == address(0) && token != address(0), "already configured");
        pcoin = IPCOINToken(token);
    }

    function allocateSeedPCOIN() external onlyOwner nonReentrant {
        require(!seedAllocated && address(pcoin) != address(0), "seed unavailable");
        seedAllocated = true;
        require(_uncommittedPCOIN() >= SEED_ALLOCATION, "insufficient seed");
        IERC20(address(pcoin)).safeTransfer(msg.sender, SEED_ALLOCATION);
    }

    function setupPairDAICOIN(address pair) external onlyOwner {
        require(pairDAICOIN == address(0) && address(pcoin) != address(0), "already set");
        _verifyPair(pair, address(pcoin), address(daicoin));
        pairDAICOIN = pair;
        pcoin.registerPair(pair);
    }

    function setupPairPLS(address pair) external onlyOwner {
        require(pairPLS == address(0) && address(pcoin) != address(0), "already set");
        require(pair != pairDAICOIN, "duplicate pair");
        require(pair != address(0) && pair.code.length > 0, "invalid pair");
        require(IV2PairPCOIN(pair).token0() == address(pcoin) ||
            IV2PairPCOIN(pair).token1() == address(pcoin), "not PCOIN pair");
        pairPLS = pair;
        pcoin.registerPair(pair);
    }

    /// @param minDAICOINOut Slippage floor for the combined 5% pDAI -> DAICOIN swap.
    function mine(uint256 pdaiAmount, uint256 referralCode, uint256 minDAICOINOut)
        external nonReentrant whenNotPaused
    {
        require(address(pcoin) != address(0) && pdaiAmount > 0, "invalid mining");
        require(!miningFinished && currentCycle <= MAX_CYCLES && cycleRemainingMiners > 0, "mining ended");
        if (!hasMined[msg.sender] && referralCode != 0) _setReferrer(msg.sender, referralCode);
        if (walletToCode[msg.sender] == 0) {
            uint256 code = nextCode++;
            walletToCode[msg.sender] = code;
            codeToWallet[code] = msg.sender;
            emit CodeGenerated(msg.sender, code);
        }
        hasMined[msg.sender] = true;

        uint256 reward = pdaiAmount / currentRate;
        require(reward > 0, "amount too small");
        uint256 actualPDAI = pdaiAmount;
        if (reward > cycleRemainingMiners) {
            reward = cycleRemainingMiners;
            actualPDAI = reward * currentRate;
        }
        uint256 lpPDAI = actualPDAI * LP_BPS / 10_000;
        uint256 dividendPDAI = actualPDAI * DIVIDEND_BPS / 10_000;
        uint256 buybackPDAI = actualPDAI * BUYBACK_BPS / 10_000;
        uint256 referralPDAI = actualPDAI * REFERRAL_BPS / 10_000;
        uint256 treasuryPDAI = actualPDAI * TREASURY_BPS / 10_000;
        uint256 returnPDAI = actualPDAI - lpPDAI - dividendPDAI - buybackPDAI - referralPDAI - treasuryPDAI;

        cycleRemainingMiners -= reward;
        outstandingPCOIN += reward;
        totalOutstandingMinerPDAI += returnPDAI;
        dividendReserve += dividendPDAI;
        uint256 posId = positions[msg.sender].length;
        positions[msg.sender].push(MinerPosition(returnPDAI, reward, block.timestamp + LOCK_DURATION, false));

        pdai.safeTransferFrom(msg.sender, address(this), pdaiAmount);
        if (pdaiAmount > actualPDAI) pdai.safeTransfer(msg.sender, pdaiAmount - actualPDAI);
        if (treasuryPDAI != 0) pdai.safeTransfer(treasury, treasuryPDAI);
        if (referralPDAI != 0) _distributeReferral(msg.sender, referralPDAI);
        if (dividendPDAI != 0) pcoin.notifyDividend(dividendPDAI);

        uint256 daicoinBought = _convertMiningDAICOIN(lpPDAI, buybackPDAI, minDAICOINOut);
        require(isSolvent(), "pDAI insolvency");
        require(_pcoinObligationsCovered(), "PCOIN insolvency");
        require(_daicoinObligationsCovered(), "DAICOIN insolvency");
        emit Mined(msg.sender, posId, actualPDAI, daicoinBought, reward, block.timestamp + LOCK_DURATION);
        if (cycleRemainingMiners == 0) {
            _advanceCycle();
            require(_pcoinObligationsCovered(), "next cycle insolvency");
        }
    }

    /// @dev Converts only the 3% LP and 2% buyback budgets to DAICOIN.
    ///      Keeps the miner's 90%, dividends, referrals and treasury in pDAI.
    function _convertMiningDAICOIN(
        uint256 lpPDAI,
        uint256 buybackPDAI,
        uint256 minDAICOINOut
    ) internal returns (uint256 daicoinBought) {
        uint256 convertPDAI = lpPDAI + buybackPDAI;
        if (convertPDAI == 0) return 0;

        uint256 beforeBalance = daicoin.balanceOf(address(this));
        _swap(address(pdai), address(daicoin), convertPDAI, minDAICOINOut);
        daicoinBought = daicoin.balanceOf(address(this)) - beforeBalance;

        uint256 lpDAICOIN = daicoinBought * lpPDAI / convertPDAI;
        accumulatedDAICOINForLP += lpDAICOIN;
        buybackAccumulatorDAICOIN += daicoinBought - lpDAICOIN;
    }

    function claim(uint256 positionId) external nonReentrant {
        require(address(pcoin) != address(0) && positionId < positions[msg.sender].length, "invalid position");
        MinerPosition storage pos = positions[msg.sender][positionId];
        require(!pos.claimed && block.timestamp >= pos.unlockTime, "not claimable");
        pos.claimed = true;
        totalOutstandingMinerPDAI -= pos.pdaiToReturn;
        outstandingPCOIN -= pos.pcoinReward;
        pdai.safeTransfer(msg.sender, pos.pdaiToReturn);
        IERC20(address(pcoin)).safeTransfer(msg.sender, pos.pcoinReward);
        emit Claimed(msg.sender, positionId, pos.pdaiToReturn, pos.pcoinReward);
    }

    /// @dev Permissionless, with caller-supplied slippage floors. LP stays in this contract.
    function flushLP(uint256 minPCOINUsed, uint256 minDAICOINUsed) external nonReentrant {
        require(address(pcoin) != address(0) && pairDAICOIN != address(0), "pair missing");
        require(block.number > lastFlushBlock && block.timestamp >= lastFlushTime + FLUSH_COOLDOWN, "cooldown");
        require(accumulatedDAICOINForLP != 0 && cycleRemainingLP != 0, "no LP budget");
        require(isSolvent() && _pcoinObligationsCovered() && _daicoinObligationsCovered(), "insolvent");
        uint256 amountDAI = accumulatedDAICOINForLP > MAX_FLUSH_AMOUNT
            ? MAX_FLUSH_AMOUNT : accumulatedDAICOINForLP;
        (uint256 rDAI, uint256 rPCOIN) = _pairReserves();
        require(rDAI != 0 && rPCOIN != 0, "empty reserves");
        uint256 desiredPCOIN = amountDAI * rPCOIN / rDAI;
        require(desiredPCOIN != 0, "too small");
        if (desiredPCOIN > cycleRemainingLP) {
            desiredPCOIN = cycleRemainingLP;
            amountDAI = desiredPCOIN * rDAI / rPCOIN;
        }
        require(amountDAI != 0 && desiredPCOIN != 0, "too small");
        lastFlushBlock = block.number;
        lastFlushTime = block.timestamp;
        IERC20(address(pcoin)).forceApprove(address(router), desiredPCOIN);
        daicoin.forceApprove(address(router), amountDAI);
        (uint256 usedDAI, uint256 usedPCOIN, uint256 liquidity) = router.addLiquidity(
            address(daicoin), address(pcoin), amountDAI, desiredPCOIN,
            minDAICOINUsed, minPCOINUsed, address(this), block.timestamp + 30 minutes);
        daicoin.forceApprove(address(router), 0);
        IERC20(address(pcoin)).forceApprove(address(router), 0);
        accumulatedDAICOINForLP -= usedDAI;
        cycleRemainingLP -= usedPCOIN;
        require(_daicoinObligationsCovered() && _pcoinObligationsCovered(), "reserve insolvency");
        emit LiquidityAdded(usedDAI, usedPCOIN, liquidity);
    }

    /// @notice Burns PCOIN bought with DAICOIN left in the LP budget, but only
    ///         after mining has ended and the reserved LP PCOIN is fully used.
    /// @dev Deliberately does not treat temporary imbalance as spendable surplus.
    ///      This protects LP commitments against future price changes/cycles.
    ///      Caller supplies an independently checked slippage floor.
    function executeSurplusPCOINBurn(uint256 amountDAICOIN, uint256 minPCOINOut)
        external nonReentrant
    {
        require(address(pcoin) != address(0) && pairDAICOIN != address(0), "pair missing");
        require(miningFinished && cycleRemainingLP == 0, "LP still committed");
        require(amountDAICOIN != 0 && amountDAICOIN <= accumulatedDAICOINForLP, "invalid surplus");
        require(isSolvent() && _pcoinObligationsCovered() && _daicoinObligationsCovered(), "insolvent");
        uint256 beforePCOIN = IERC20(address(pcoin)).balanceOf(address(this));
        _swap(address(daicoin), address(pcoin), amountDAICOIN, minPCOINOut);
        uint256 acquired = IERC20(address(pcoin)).balanceOf(address(this)) - beforePCOIN;
        require(acquired != 0, "zero PCOIN");
        accumulatedDAICOINForLP -= amountDAICOIN;
        pcoin.burn(acquired);
        require(isSolvent() && _pcoinObligationsCovered() && _daicoinObligationsCovered(), "reserve insolvency");
        emit SurplusPCOINBurnExecuted(amountDAICOIN, acquired);
    }

    /// @dev Uses the DAICOIN bought with 2% of mining deposits to purchase
    ///      MINTCOIN and send it to the conventional dead address.
    ///      This does NOT decrease MINTCOIN.totalSupply().
    function executeBuyback(uint256 amountDAICOIN, uint256 minMINTCOINOut) external nonReentrant {
        require(address(pcoin) != address(0), "token missing");
        require(amountDAICOIN >= MIN_BUYBACK && amountDAICOIN <= buybackAccumulatorDAICOIN, "invalid amount");
        require(isSolvent() && _pcoinObligationsCovered() && _daicoinObligationsCovered(), "insolvent");
        uint256 beforeMINT = mintcoin.balanceOf(address(this));
        _swap(address(daicoin), address(mintcoin), amountDAICOIN, minMINTCOINOut);
        uint256 acquired = mintcoin.balanceOf(address(this)) - beforeMINT;
        require(acquired != 0, "zero output");
        buybackAccumulatorDAICOIN -= amountDAICOIN;
        mintcoin.safeTransfer(BURN_ADDRESS, acquired);
        require(_daicoinObligationsCovered(), "DAICOIN insolvency");
        emit BuybackExecuted(amountDAICOIN, acquired);
    }

    /// @dev Permissionless processing of 5% sell fees to MINTCOIN at DEAD.
    ///      This does NOT decrease MINTCOIN.totalSupply().
    function settleSellFeeBurn(uint256 pcoinAmount, uint256 minDAICOINOut, uint256 minMINTCOINOut)
        external nonReentrant
    {
        require(address(pcoin) != address(0), "token missing");
        uint256 available = pcoin.totalSellFeesCollected() - sellFeesProcessed;
        require(pcoinAmount != 0 && pcoinAmount <= available, "fee unavailable");
        require(_pcoinObligationsCovered() && isSolvent() && _daicoinObligationsCovered(), "insolvent");
        uint256 beforeDAI = daicoin.balanceOf(address(this));
        _swap(address(pcoin), address(daicoin), pcoinAmount, minDAICOINOut);
        uint256 intermediate = daicoin.balanceOf(address(this)) - beforeDAI;
        require(intermediate != 0, "zero DAICOIN");
        uint256 beforeMINT = mintcoin.balanceOf(address(this));
        _swap(address(daicoin), address(mintcoin), intermediate, minMINTCOINOut);
        uint256 acquired = mintcoin.balanceOf(address(this)) - beforeMINT;
        require(acquired != 0, "zero MINTCOIN");
        sellFeesProcessed += pcoinAmount;
        mintcoin.safeTransfer(BURN_ADDRESS, acquired);
        require(_daicoinObligationsCovered(), "DAICOIN insolvency");
        require(_pcoinObligationsCovered(), "PCOIN insolvency");
        emit SellFeeBurnExecuted(pcoinAmount, intermediate, acquired);
    }

    /// @notice Permissionless flush of dividends queued while no PCOIN holders were eligible.
    function flushQueuedDividends() external nonReentrant {
        require(address(pcoin) != address(0), "token missing");
        pcoin.notifyDividend(0);
    }

    function claimDividend() external nonReentrant {
        require(address(pcoin) != address(0), "token missing");
        uint256 owed = pcoin.consumeDividend(msg.sender);
        require(owed >= MIN_DIVIDEND_CLAIM && owed <= dividendReserve, "not claimable");
        dividendReserve -= owed;
        pdai.safeTransfer(msg.sender, owed);
        emit DividendClaimed(msg.sender, owed);
    }

    function isSolvent() public view returns (bool) {
        return pdai.balanceOf(address(this)) >= totalOutstandingMinerPDAI + dividendReserve;
    }

    function getPositionCount(address miner) external view returns (uint256) { return positions[miner].length; }
    function getPosition(address miner, uint256 id) external view returns (MinerPosition memory) {
        return positions[miner][id];
    }
    function estimatePCOIN(uint256 amountPDAI) external view returns (uint256) {
        if (miningFinished || currentRate == 0 || cycleRemainingMiners == 0) return 0;
        uint256 amount = amountPDAI / currentRate;
        return amount > cycleRemainingMiners ? cycleRemainingMiners : amount;
    }
    function pendingDividend(address account) external view returns (uint256) {
        return address(pcoin) == address(0) ? 0 : pcoin.pendingDividend(account);
    }
    function availableSellFees() external view returns (uint256) {
        return address(pcoin) == address(0) ? 0 : pcoin.totalSellFeesCollected() - sellFeesProcessed;
    }
    function _daicoinObligationsCovered() internal view returns (bool) {
        return daicoin.balanceOf(address(this)) >= accumulatedDAICOINForLP + buybackAccumulatorDAICOIN;
    }

    function _pcoinObligationsCovered() internal view returns (bool) {
        return IERC20(address(pcoin)).balanceOf(address(this)) >=
            outstandingPCOIN + cycleRemainingMiners + cycleRemainingLP +
            (seedAllocated ? 0 : SEED_ALLOCATION) + (pcoin.totalSellFeesCollected() - sellFeesProcessed);
    }
    function _uncommittedPCOIN() internal view returns (uint256) {
        uint256 requiredBalance = outstandingPCOIN + cycleRemainingMiners + cycleRemainingLP +
            (pcoin.totalSellFeesCollected() - sellFeesProcessed);
        uint256 balance = IERC20(address(pcoin)).balanceOf(address(this));
        return balance > requiredBalance ? balance - requiredBalance : 0;
    }
    /// @dev Reserve only what is physically uncommitted. The theoretical 32-cycle
    ///      schedule nearly equals 21M, so the 100k seed must reduce later cycles.
    ///      Never reduce rewards already promised or LP already reserved.
    function _advanceCycle() internal {
        if (currentCycle >= MAX_CYCLES) {
            miningFinished = true;
            emit MiningFinished(currentCycle);
            return;
        }

        uint256 balance = IERC20(address(pcoin)).balanceOf(address(this));
        uint256 committed = outstandingPCOIN + cycleRemainingLP +
            (seedAllocated ? 0 : SEED_ALLOCATION) +
            (pcoin.totalSellFeesCollected() - sellFeesProcessed);
        require(balance >= committed, "cycle reserve insolvency");
        uint256 available = balance - committed;

        uint256 nextCycle = currentCycle + 1;
        uint256 theoreticalEmission = INITIAL_CYCLE_EMISSION >> (nextCycle - 1);
        uint256 emission = theoreticalEmission < available ? theoreticalEmission : available;
        uint256 miners = emission * MINER_SHARE / 100;
        if (miners == 0) {
            miningFinished = true;
            emit MiningFinished(currentCycle);
            return;
        }

        currentCycle = nextCycle;
        currentRate *= 2;
        cycleRemainingMiners = miners;
        cycleRemainingLP += emission - miners;
        emit CycleAdvanced(currentCycle, currentRate);
    }

    function _setReferrer(address miner, uint256 code) internal {
        address ref = codeToWallet[code];
        if (ref == address(0) || ref == miner || !hasMined[ref]) return;
        address cursor = ref;
        for (uint8 i; i < 3; ++i) {
            if (cursor == miner) return;
            cursor = referrer[cursor];
            if (cursor == address(0)) break;
        }
        referrer[miner] = ref;
    }
    function _distributeReferral(address miner, uint256 total) internal {
        address l1 = referrer[miner];
        address l2 = l1 == address(0) ? address(0) : referrer[l1];
        address l3 = l2 == address(0) ? address(0) : referrer[l2];
        uint256 first = total * 50 / 100;
        uint256 second = total * 30 / 100;
        _payRef(l1, first);
        _payRef(l2, second);
        _payRef(l3, total - first - second);
    }
    function _payRef(address to, uint256 amount) internal {
        if (amount != 0) pdai.safeTransfer(to != address(0) && hasMined[to] ? to : treasury, amount);
    }
    function _verifyPair(address pair, address tokenA, address tokenB) internal view {
        require(pair != address(0) && pair.code.length > 0, "invalid pair");
        address t0 = IV2PairPCOIN(pair).token0();
        address t1 = IV2PairPCOIN(pair).token1();
        require((t0 == tokenA && t1 == tokenB) || (t0 == tokenB && t1 == tokenA), "wrong pair");
    }
    function _pairReserves() internal view returns (uint256 reserveDAI, uint256 reservePCOIN) {
        (uint112 r0, uint112 r1,) = IV2PairPCOIN(pairDAICOIN).getReserves();
        bool daiFirst = IV2PairPCOIN(pairDAICOIN).token0() == address(daicoin);
        reserveDAI = daiFirst ? uint256(r0) : uint256(r1);
        reservePCOIN = daiFirst ? uint256(r1) : uint256(r0);
    }
    function _swap(address input, address output, uint256 amount, uint256 minOut) internal {
        require(amount != 0 && minOut != 0, "swap minOut required");
        address[] memory path = new address[](2);
        path[0] = input;
        path[1] = output;
        IERC20(input).forceApprove(address(router), amount);
        router.swapExactTokensForTokens(amount, minOut, path, address(this), block.timestamp + 30 minutes);
        IERC20(input).forceApprove(address(router), 0);
    }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
    function recoverToken(address token, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(pdai) && token != address(daicoin) &&
            token != address(pcoin) && token != address(mintcoin), "protected token");
        IERC20(token).safeTransfer(owner(), amount);
    }
    receive() external payable { revert("no native deposits"); }
}
