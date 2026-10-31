// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PCOINToken
/// @author MINTer
/// @notice Fork of PMINTToken: dividends remain denominated in pDAI and are
/// accounted for by the mining contract. Sell fees are collected in PCOIN,
/// then swapped and burned by PCOINMining in a separate permissionless call.
contract PCOINToken is ERC20 {
    uint256 public constant MAX_SUPPLY = 21_000_000 ether;
    uint256 public constant SELL_FEE_BPS = 500;
    address public immutable miningContract;
    address public pairA;
    address public pairB;
    uint8 public pairCount;
    uint256 public rewardPerTokenStored;
    uint256 public queuedDividends;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public dividendsPending;
    mapping(address => bool) public isExempt;
    uint256 public exemptSupply;
    uint256 public totalSellFeesCollected;
    event PairRegistered(address indexed pair);
    event SellFeeCollected(address indexed seller, uint256 amount);

    constructor(address mining_) ERC20("pCOIN", "pCOIN") {
        require(mining_ != address(0), "zero mining");
        miningContract = mining_;
        isExempt[mining_] = true;
        _mint(mining_, MAX_SUPPLY); // hook accounts for the exempt minted balance
    }
    modifier onlyMining() { require(msg.sender == miningContract, "only mining"); _; }

    function registerPair(address pair) external onlyMining {
        require(pairCount < 2 && pair != address(0) && !isExempt[pair], "invalid pair");
        // Settle accrued rewards before the pair becomes exempt.
        _checkpoint(pair);
        isExempt[pair] = true;
        exemptSupply += balanceOf(pair);
        if (pairA == address(0)) pairA = pair;
        else pairB = pair;
        ++pairCount;
        emit PairRegistered(pair);
    }
    function notifyDividend(uint256 amount) external onlyMining {
        queuedDividends += amount;
        uint256 supply = effectiveSupply();
        if (supply != 0 && queuedDividends != 0) {
            uint256 increment = queuedDividends * 1e18 / supply;
            if (increment != 0) {
                uint256 distributed = increment * supply / 1e18;
                queuedDividends -= distributed;
                rewardPerTokenStored += increment;
            }
        }
    }
    function consumeDividend(address account) external onlyMining returns (uint256 owed) {
        _checkpoint(account);
        owed = dividendsPending[account];
        dividendsPending[account] = 0;
    }
    function burn(uint256 amount) external onlyMining { _burn(miningContract, amount); }
    function isRegisteredPair(address account) public view returns (bool) {
        return account != address(0) && (account == pairA || account == pairB);
    }
    function effectiveSupply() public view returns (uint256) {
        return totalSupply() - exemptSupply;
    }
    function pendingDividend(address account) public view returns (uint256) {
        if (account == address(0) || isExempt[account]) return dividendsPending[account];
        return dividendsPending[account] + balanceOf(account) *
            (rewardPerTokenStored - userRewardPerTokenPaid[account]) / 1e18;
    }
    function _checkpoint(address account) internal {
        if (account == address(0) || isExempt[account]) return;
        uint256 delta = rewardPerTokenStored - userRewardPerTokenPaid[account];
        if (delta != 0) dividendsPending[account] += balanceOf(account) * delta / 1e18;
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    // OpenZeppelin 5.x uses _update instead of _beforeTokenTransfer/_transfer overrides.
    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0) &&
            isRegisteredPair(to) && !isExempt[from]) {
            uint256 fee = amount * SELL_FEE_BPS / 10_000;
            _accountedUpdate(from, to, amount - fee);
            if (fee != 0) {
                _accountedUpdate(from, miningContract, fee);
                totalSellFeesCollected += fee;
                emit SellFeeCollected(from, fee);
            }
        } else {
            _accountedUpdate(from, to, amount);
        }
    }

    function _accountedUpdate(address from, address to, uint256 amount) private {
        _checkpoint(from);
        _checkpoint(to);
        bool fromEx = from != address(0) && isExempt[from];
        bool toEx = to != address(0) && isExempt[to];
        if (fromEx && !toEx) exemptSupply -= amount;
        if (!fromEx && toEx) exemptSupply += amount;
        super._update(from, to, amount);
    }
}
