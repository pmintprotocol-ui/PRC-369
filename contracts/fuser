// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC721/ERC721.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/IERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/ReentrancyGuard.sol";

contract FUSEReserve is ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant RESERVE_AMOUNT = 5_555;
    uint256 public constant CP_PER_RESERVE = 5_555;
    uint256 public constant RESERVE_DURATION = 369 days;
    uint256 public constant ELIGIBILITY_DELAY = 24 hours;
    uint256 public constant TOKEN_REGISTRATION_FEE = 100_000 ether;
    uint256 public constant RESERVE_CREATION_FEE = 369 ether;
    uint256 public constant BPS = 10_000;
    uint256 public constant EXIT_RETURN_BPS = 5_000;
    uint256 public constant REWARD_PRECISION = 1e36;
    uint256 public constant MAX_SYNC_STEPS = 500;

    // FUSEReserve is intentionally bound to PulseChain mainnet.
    uint256 public constant PULSECHAIN_CHAIN_ID = 369;

    // Permanent protocol provenance embedded in every FUSEReserve NFT.
    string public constant PROTOCOL_BRAND = "MINTer";
    string public constant FUSER_IDENTITY = "FUSEr";

    address public constant CV_ADDRESS = 0x83c8b596B0825326707F5BC88E2bd2a052d3FfBa;
    address public constant MINTER_ADDRESS = 0x2c25a1080078D0C6Fc1e5a81683573975Cfd65c8;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    IERC20 public immutable CV;

    struct TokenConfig {
        bool registered;
        uint8 decimals;
        uint64 registeredAt;
        address registeredBy;
        uint256 activeReserves;
    }

    struct TokenIdentity {
        string name;
        string symbol;
        string logoURI;
        bytes32 logoHash;
        address tokenContract;
        uint256 chainId;
        uint256 totalSupplyAtRegistration;
        uint64 registeredAt;
        bytes32 tokenIdentityHash;
    }

    struct ReserveCustomization {
        // CSS-style hex strings chosen by the creator, e.g. "#111111".
        string cardColor;
        string borderColor;
        string logoBackgroundColor;
        string message;
        string initials;
        bytes32 positionIdentityHash;
    }

    struct Reserve {
        address token;
        uint64 createdAt;
        uint64 unlockTime;
        uint256 rawAmount;
    }

    struct Distribution {
        uint64 timestamp;
        uint256 amount;
        uint256 eligibleCP;
        uint256 rewardPerCP;
        uint256 cumulativeIndex;
        uint256 globalSequence;
    }

    mapping(address => TokenConfig) public tokenConfig;
    mapping(address => TokenIdentity) public tokenIdentity;

    address[] public registeredTokens;
    mapping(uint256 => Reserve) public reserves;
    mapping(uint256 => ReserveCustomization) public reserveCustomization;
    mapping(uint256 => address) public positionToken;
    uint256 public nextReserveId = 1;

    mapping(address => mapping(uint256 => Distribution)) public distributions;
    mapping(address => uint256) public distributionCount;

    // rewardToken => current cumulative reward-per-CP index.
    mapping(address => uint256) public globalRewardIndex;

    // Monotonic sequence shared by every reward distribution, regardless of
    // reward token. This lets a closed reserve freeze its reward rights at
    // the exact protocol event ordering, even when multiple transactions
    // share the same block timestamp.
    uint256 public globalDistributionSequence;

    // reserveId => rewardToken => cumulative index already accounted for.
    mapping(uint256 => mapping(address => uint256)) public claimedRewardIndex;
    mapping(uint256 => mapping(address => bool)) public rewardIndexInitialized;

    // Owner preserved after principal exit so historical rewards remain claimable.
    mapping(uint256 => address) public rewardOwner;
    mapping(uint256 => uint64) public rewardEligibleAt;

    // 0 while the reserve is live. On complete/emergency exit this freezes
    // the last global distribution sequence the NFT is entitled to claim.
    mapping(uint256 => uint256) public rewardEndSequence;

    uint256 public totalActiveCP;
    uint256 public totalEligibleCP;
    uint256 public activeReserveCount;

    // Eligibility queue checkpoint.
    // Reserve IDs are chronological, so we only process each reserve once
    // when its 24-hour eligibility time arrives.
    uint256 public eligibilityCursor = 1;
    mapping(uint256 => bool) public eligibilityProcessed;
    mapping(uint256 => bool) public reserveEligible;
    uint256 public totalRegistrationCV;
    uint256 public totalCreationCV;
    uint256 public totalEmergencyRewards;

    // Solvency accounting:
    // principalLiability[token] is principal still owed to active reserves.
    // rewardLiability[token] is reward value allocated by distributions but
    // not yet paid to claimants. These liabilities must remain segregated
    // mathematically even though the ERC20 balance is held by one contract.
    mapping(address => uint256) public principalLiability;
    mapping(address => uint256) public rewardLiability;
    mapping(address => uint256) public totalRewardsClaimed;
    mapping(address => uint256) public totalInjectedRewards;
    mapping(address => uint256) public totalDistributedRewards;
    mapping(address => uint256) public totalBurnedRewards;
    mapping(address => uint256) public rewardDust;

    error ZeroAddress();
    error InvalidToken();
    error InvalidTokenDecimals();
    error TokenAlreadyRegistered();
    error TokenNotRegistered();
    error InvalidReserve();
    error NotOwner();
    error StillLocked();
    error AlreadyMatured();
    error TransferBlocked();
    error AmountZero();
    error NoReward();
    error FeeOnTransferNotSupported();
    error NoEligibleCP();
    error EligibilitySyncRequired();
    error SyncLimitZero();
    error NotRewardOwner();
    error InsolventToken(address token);
    error InvalidCustomization();
    error MetadataLocked();
    error WrongChain(uint256 expected, uint256 actual);
    error InvalidLogoMetadata();

    event ProtocolProvenance(uint256 indexed reserveId,string brand,string fuseIdentity,uint256 chainId,address indexed tokenContract,bytes32 positionIdentityHash);
    event TokenIdentityRegistered(address indexed token,uint256 indexed chainId,string name,string symbol,string logoURI,bytes32 logoHash,uint256 totalSupplyAtRegistration,bytes32 tokenIdentityHash);
    event ReserveCustomized(uint256 indexed reserveId,bytes32 indexed positionIdentityHash,string cardColor,string borderColor,string logoBackgroundColor,string message,string initials);
    event TokenRegistered(address indexed token,address indexed registrar,uint8 decimals,uint256 cvFee);
    event ReserveCreated(uint256 indexed reserveId,address indexed owner,address indexed token,uint256 rawAmount,uint256 cp,uint256 createdAt,uint256 eligibleAt,uint256 unlockTime);
    event RewardInjected(address indexed rewardToken,address indexed sender,uint256 amount);
    event RewardDistributed(address indexed rewardToken,uint256 indexed distributionId,uint256 amount,uint256 eligibleCP,uint256 rewardPerCP,uint256 cumulativeIndex,uint256 globalSequence,uint256 timestamp,bytes32 indexed reason);
    event RewardClaimed(uint256 indexed reserveId,address indexed owner,address indexed rewardToken,uint256 amount,uint256 newRewardIndex);
    event ReserveCompleted(uint256 indexed reserveId,address indexed owner,address indexed token,uint256 returnedAmount);
    event EmergencyExit(uint256 indexed reserveId,address indexed owner,address indexed token,uint256 returnedAmount,uint256 rewardAmount,uint256 burnedAmount);
    event EligibilityActivated(uint256 indexed reserveId,uint256 eligibleAt,uint256 totalEligibleCP);

    constructor() ERC721("FUSE Conviction Reserve", "FUSERESERVE") {
        if (block.chainid != PULSECHAIN_CHAIN_ID) {
            revert WrongChain(
                PULSECHAIN_CHAIN_ID,
                block.chainid
            );
        }

        CV = IERC20(CV_ADDRESS);
    }

    /**
     * @notice Registers a PulseChain token once with its permanent visual identity.
     * @dev The launcher uploads the logo off-chain first (for example to IPFS),
     *      computes logoHash from the exact file bytes, then submits logoURI and
     *      logoHash here. Because registration is one-time and there is no logo
     *      update function, the original logo commitment is immutable.
     */
    function registerToken(
        address token,
        string calldata logoURI,
        bytes32 logoHash
    ) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (token.code.length == 0) revert InvalidToken();
        if (
            bytes(logoURI).length == 0 ||
            bytes(logoURI).length > 256 ||
            logoHash == bytes32(0)
        ) revert InvalidLogoMetadata();
        TokenConfig storage cfg = tokenConfig[token];
        if (cfg.registered) revert TokenAlreadyRegistered();

        uint8 decimals = _readDecimals(token);
        uint256 registrationTokenAmount =
            RESERVE_AMOUNT * (10 ** uint256(decimals));

        CV.safeTransferFrom(
            msg.sender,
            MINTER_ADDRESS,
            TOKEN_REGISTRATION_FEE
        );

        // First registration also commits exactly 5,555 whole units
        // of the listed token directly to the MINTer wallet.
        IERC20 listedToken = IERC20(token);
        uint256 minterBefore =
            listedToken.balanceOf(MINTER_ADDRESS);

        listedToken.safeTransferFrom(
            msg.sender,
            MINTER_ADDRESS,
            registrationTokenAmount
        );

        if (
            listedToken.balanceOf(MINTER_ADDRESS) -
            minterBefore != registrationTokenAmount
        ) revert FeeOnTransferNotSupported();

        _finalizeTokenRegistration(
            token,
            logoURI,
            logoHash,
            decimals,
            cfg
        );
    }

    /**
     * @dev Split out of registerToken to keep the external registration
     *      function below Solidity's stack-depth limit in Remix.
     */
    function _finalizeTokenRegistration(
        address token,
        string calldata logoURI,
        bytes32 logoHash,
        uint8 decimals,
        TokenConfig storage cfg
    ) internal {
        string memory tokenName = _readName(token);
        string memory tokenSymbol = _readSymbol(token);
        uint256 tokenSupply = _readTotalSupply(token);

        bytes32 identityHash = keccak256(
            abi.encode(
                PULSECHAIN_CHAIN_ID,
                token,
                tokenName,
                tokenSymbol,
                decimals,
                logoHash
            )
        );

        tokenIdentity[token] = TokenIdentity({
            name: tokenName,
            symbol: tokenSymbol,
            logoURI: logoURI,
            logoHash: logoHash,
            tokenContract: token,
            chainId: PULSECHAIN_CHAIN_ID,
            totalSupplyAtRegistration: tokenSupply,
            registeredAt: uint64(block.timestamp),
            tokenIdentityHash: identityHash
        });

        cfg.registered = true;
        cfg.decimals = decimals;
        cfg.registeredAt = uint64(block.timestamp);
        cfg.registeredBy = msg.sender;

        registeredTokens.push(token);
        totalRegistrationCV += TOKEN_REGISTRATION_FEE;

        emit TokenRegistered(
            token,
            msg.sender,
            decimals,
            TOKEN_REGISTRATION_FEE
        );

        _emitTokenIdentityRegistered(
            token,
            tokenName,
            tokenSymbol,
            logoURI,
            logoHash,
            tokenSupply,
            identityHash
        );
    }

    /**
     * @dev Separate event helper avoids keeping the complete registration
     *      frame alive while encoding a large dynamic event.
     */
    function _emitTokenIdentityRegistered(
        address token,
        string memory tokenName,
        string memory tokenSymbol,
        string calldata logoURI,
        bytes32 logoHash,
        uint256 tokenSupply,
        bytes32 identityHash
    ) internal {
        emit TokenIdentityRegistered(
            token,
            PULSECHAIN_CHAIN_ID,
            tokenName,
            tokenSymbol,
            logoURI,
            logoHash,
            tokenSupply,
            identityHash
        );
    }

    function createReserve(
        address token,
        string calldata cardColor,
        string calldata borderColor,
        string calldata logoBackgroundColor,
        string calldata message,
        string calldata initials
    ) external nonReentrant returns (uint256 reserveId) {
        TokenConfig storage cfg = tokenConfig[token];
        if (!cfg.registered) revert TokenNotRegistered();

        _validateCustomization(
            cardColor,
            borderColor,
            logoBackgroundColor,
            message,
            initials
        );

        uint256 rawAmount = _collectReserveAssets(token, cfg.decimals);

        reserveId = nextReserveId++;
        _initializeReservePosition(
            reserveId,
            token,
            rawAmount,
            cfg
        );

        bytes32 positionIdentityHash = _buildPositionIdentity(
            token,
            reserveId,
            msg.sender
        );

        _storeReserveCustomization(
            reserveId,
            cardColor,
            borderColor,
            logoBackgroundColor,
            message,
            initials,
            positionIdentityHash
        );

        _mintReservePosition(reserveId, msg.sender);

        _emitReserveCreationEvents(reserveId);
    }

    function _validateCustomization(
        string calldata cardColor,
        string calldata borderColor,
        string calldata logoBackgroundColor,
        string calldata message,
        string calldata initials
    ) internal pure {
        if (
            bytes(cardColor).length > 16 ||
            bytes(borderColor).length > 16 ||
            bytes(logoBackgroundColor).length > 16 ||
            bytes(message).length > 160 ||
            bytes(initials).length > 12
        ) revert InvalidCustomization();
    }

    function _collectReserveAssets(
        address token,
        uint8 decimals
    ) internal returns (uint256 rawAmount) {
        rawAmount = RESERVE_AMOUNT * (10 ** uint256(decimals));

        CV.safeTransferFrom(
            msg.sender,
            MINTER_ADDRESS,
            RESERVE_CREATION_FEE
        );

        IERC20 asset = IERC20(token);
        uint256 beforeBalance = asset.balanceOf(address(this));

        asset.safeTransferFrom(
            msg.sender,
            address(this),
            rawAmount
        );

        if (
            asset.balanceOf(address(this)) - beforeBalance != rawAmount
        ) revert FeeOnTransferNotSupported();
    }

    function _initializeReservePosition(
        uint256 reserveId,
        address token,
        uint256 rawAmount,
        TokenConfig storage cfg
    ) internal {
        Reserve storage r = reserves[reserveId];
        r.token = token;
        r.createdAt = uint64(block.timestamp);
        r.unlockTime = uint64(block.timestamp + RESERVE_DURATION);
        r.rawAmount = rawAmount;

        positionToken[reserveId] = token;
        principalLiability[token] += rawAmount;

        cfg.activeReserves++;
        activeReserveCount++;
        totalActiveCP += CP_PER_RESERVE;
        totalCreationCV += RESERVE_CREATION_FEE;

        rewardOwner[reserveId] = msg.sender;
        rewardEligibleAt[reserveId] =
            uint64(block.timestamp + ELIGIBILITY_DELAY);
    }

    function _buildPositionIdentity(
        address token,
        uint256 reserveId,
        address creator
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                PULSECHAIN_CHAIN_ID,
                address(this),
                keccak256(bytes(PROTOCOL_BRAND)),
                keccak256(bytes(FUSER_IDENTITY)),
                token,
                reserveId,
                creator,
                block.timestamp
            )
        );
    }

    function _storeReserveCustomization(
        uint256 reserveId,
        string calldata cardColor,
        string calldata borderColor,
        string calldata logoBackgroundColor,
        string calldata message,
        string calldata initials,
        bytes32 positionIdentityHash
    ) internal {
        ReserveCustomization storage c = reserveCustomization[reserveId];

        c.cardColor = cardColor;
        c.borderColor = borderColor;
        c.logoBackgroundColor = logoBackgroundColor;
        c.message = message;
        c.initials = initials;
        c.positionIdentityHash = positionIdentityHash;
    }

    function _mintReservePosition(
        uint256 reserveId,
        address owner
    ) internal {
        _safeMint(owner, reserveId);
    }

    function _emitReserveCreationEvents(uint256 reserveId) internal {
        Reserve storage r = reserves[reserveId];
        bytes32 identityHash = reserveCustomization[reserveId].positionIdentityHash;

        emit ReserveCreated(
            reserveId,
            msg.sender,
            r.token,
            r.rawAmount,
            CP_PER_RESERVE,
            r.createdAt,
            rewardEligibleAt[reserveId],
            r.unlockTime
        );

        _emitReserveCustomized(reserveId, identityHash);

        emit ProtocolProvenance(
            reserveId,
            PROTOCOL_BRAND,
            FUSER_IDENTITY,
            PULSECHAIN_CHAIN_ID,
            r.token,
            identityHash
        );
    }

    function _emitReserveCustomized(
        uint256 reserveId,
        bytes32 positionIdentityHash
    ) internal {
        ReserveCustomization storage c = reserveCustomization[reserveId];

        emit ReserveCustomized(
            reserveId,
            positionIdentityHash,
            c.cardColor,
            c.borderColor,
            c.logoBackgroundColor,
            c.message,
            c.initials
        );
    }

    function completeReserve(uint256 reserveId) external nonReentrant {
        if (ownerOf(reserveId) != msg.sender) revert NotOwner();
        Reserve memory r = reserves[reserveId];
        if (r.token == address(0)) revert InvalidReserve();
        if (block.timestamp < r.unlockTime) revert StillLocked();

        _syncEligibleCP(MAX_SYNC_STEPS);
        if (!_eligibilitySyncedNow()) revert EligibilitySyncRequired();

        // Freeze reward rights at the exact protocol sequence before the
        // position is closed. Historical unclaimed rewards remain claimable;
        // future distributions do not.
        rewardEndSequence[reserveId] = globalDistributionSequence;

        _deactivateReserve(reserveId,r);

        principalLiability[r.token] -= r.rawAmount;
        _assertSolvent(r.token);

        IERC20(r.token).safeTransfer(msg.sender,r.rawAmount);

        _assertSolvent(r.token);
        emit ReserveCompleted(reserveId,msg.sender,r.token,r.rawAmount);
    }

    function emergencyExit(uint256 reserveId) external nonReentrant {
        if (ownerOf(reserveId) != msg.sender) revert NotOwner();
        Reserve memory r = reserves[reserveId];
        if (r.token == address(0)) revert InvalidReserve();
        if (block.timestamp >= r.unlockTime) revert AlreadyMatured();

        // Bring all reserves whose 24h delay has elapsed into eligible CP.
        // This occurs BEFORE removing the exiting reserve. If the exiting
        // reserve is already eligible, _deactivateReserve removes its CP
        // before the reward snapshot (Model A).
        _syncEligibleCP(MAX_SYNC_STEPS);
        if (!_eligibilitySyncedNow()) revert EligibilitySyncRequired();

        // Freeze this NFT's reward rights before creating the emergency-exit
        // distribution. It therefore cannot receive its own penalty or any
        // later reward.
        rewardEndSequence[reserveId] = globalDistributionSequence;

        _deactivateReserve(reserveId,r);

        // The full principal obligation for this reserve ends here.
        // Half becomes an owner payout and half becomes reward liability
        // (or is burned if there is no eligible CP).
        principalLiability[r.token] -= r.rawAmount;

        uint256 returnedAmount = (r.rawAmount * EXIT_RETURN_BPS) / BPS;
        uint256 rewardAmount = r.rawAmount - returnedAmount;
        uint256 eligibleCP = totalEligibleCP;
        uint256 burnedAmount;

        if (eligibleCP == 0) {
            IERC20(r.token).safeTransfer(BURN_ADDRESS,rewardAmount);
            totalBurnedRewards[r.token] += rewardAmount;
            burnedAmount = rewardAmount;
        } else {
            _createDistribution(r.token,rewardAmount,eligibleCP,keccak256("EMERGENCY_EXIT"));
            totalEmergencyRewards += rewardAmount;
        }

        _assertSolvent(r.token);

        IERC20(r.token).safeTransfer(msg.sender,returnedAmount);

        _assertSolvent(r.token);

        emit EmergencyExit(reserveId,msg.sender,r.token,returnedAmount,rewardAmount,burnedAmount);
    }

    function injectReward(address rewardToken,uint256 amount) external nonReentrant {
        if (!tokenConfig[rewardToken].registered) revert TokenNotRegistered();
        if (amount == 0) revert AmountZero();

        IERC20 asset = IERC20(rewardToken);
        uint256 beforeBalance = asset.balanceOf(address(this));
        asset.safeTransferFrom(msg.sender,address(this),amount);
        if (asset.balanceOf(address(this)) - beforeBalance != amount) revert FeeOnTransferNotSupported();

        emit RewardInjected(rewardToken,msg.sender,amount);

        // Amortized checkpoint update: only newly matured reserve IDs are
        // processed. No scan over the full historical reserve set.
        _syncEligibleCP(MAX_SYNC_STEPS);
        if (!_eligibilitySyncedNow()) revert EligibilitySyncRequired();

        uint256 eligibleCP = totalEligibleCP;
        if (eligibleCP == 0) revert NoEligibleCP();

        totalInjectedRewards[rewardToken] += amount;
        _createDistribution(
            rewardToken,
            amount,
            eligibleCP,
            keccak256("MANUAL_INJECTION")
        );

        _assertSolvent(rewardToken);
    }

    /**
     * @notice Returns currently claimable reward for one reserve/reward token.
     *
     * First lookup is O(log N) because it binary-searches the historical
     * distribution checkpoint immediately before the reserve became eligible.
     * After the first successful claim, subsequent claims are O(1).
     */
    function pendingReward(
        uint256 reserveId,
        address rewardToken
    ) public view returns (uint256 amount) {
        uint256 eligibleAt = rewardEligibleAt[reserveId];
        if (eligibleAt == 0) revert InvalidReserve();

        uint256 currentIndex = _claimableCurrentIndex(reserveId, rewardToken);
        if (currentIndex == 0) return 0;

        uint256 accountedIndex;

        if (rewardIndexInitialized[reserveId][rewardToken]) {
            accountedIndex =
                claimedRewardIndex[reserveId][rewardToken];
        } else {
            // Excludes every distribution strictly before eligibility.
            // A distribution at exactly eligibleAt DOES qualify.
            accountedIndex =
                _rewardIndexBefore(rewardToken, eligibleAt);
        }

        if (currentIndex <= accountedIndex) return 0;

        amount =
            (CP_PER_RESERVE *
                (currentIndex - accountedIndex)) /
            REWARD_PRECISION;
    }

    /**
     * @notice Claims one reward token.
     * @dev O(log N) only on the first claim for this reserve/reward-token pair;
     *      O(1) afterward regardless of historical distribution count.
     */
    function claimReward(
        uint256 reserveId,
        address rewardToken
    )
        external
        nonReentrant
        returns (uint256 amount)
    {
        address liveOwner = _ownerOf(reserveId);
        if (liveOwner != address(0)) {
            if (liveOwner != msg.sender) revert NotOwner();
        } else {
            if (rewardOwner[reserveId] != msg.sender)
                revert NotRewardOwner();
        }

        uint256 eligibleAt = rewardEligibleAt[reserveId];
        if (eligibleAt == 0) revert InvalidReserve();

        uint256 currentIndex = _claimableCurrentIndex(reserveId, rewardToken);
        uint256 accountedIndex;

        if (rewardIndexInitialized[reserveId][rewardToken]) {
            accountedIndex =
                claimedRewardIndex[reserveId][rewardToken];
        } else {
            accountedIndex =
                _rewardIndexBefore(rewardToken, eligibleAt);
        }

        if (currentIndex <= accountedIndex) revert NoReward();

        amount =
            (CP_PER_RESERVE *
                (currentIndex - accountedIndex)) /
            REWARD_PRECISION;

        if (amount == 0) revert NoReward();

        // Effects before interaction.
        rewardIndexInitialized[reserveId][rewardToken] = true;
        claimedRewardIndex[reserveId][rewardToken] = currentIndex;

        rewardLiability[rewardToken] -= amount;
        totalRewardsClaimed[rewardToken] += amount;

        IERC20(rewardToken).safeTransfer(msg.sender, amount);

        _assertSolvent(rewardToken);

        emit RewardClaimed(
            reserveId,
            msg.sender,
            rewardToken,
            amount,
            currentIndex
        );
    }

    /**
     * @notice Claims a caller-selected list of reward tokens.
     * @dev No unbounded scan of registered tokens or historical distributions.
     *      Each token is O(1) after its first reserve/token claim.
     */
    function claimRewards(
        uint256 reserveId,
        address[] calldata rewardTokens
    )
        external
        nonReentrant
        returns (uint256 claimedTokenTypes)
    {
        address liveOwner = _ownerOf(reserveId);
        if (liveOwner != address(0)) {
            if (liveOwner != msg.sender) revert NotOwner();
        } else {
            if (rewardOwner[reserveId] != msg.sender)
                revert NotRewardOwner();
        }

        uint256 eligibleAt = rewardEligibleAt[reserveId];
        if (eligibleAt == 0) revert InvalidReserve();

        for (uint256 i; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];

            uint256 currentIndex =
                _claimableCurrentIndex(
                    reserveId,
                    rewardToken
                );

            if (currentIndex == 0) continue;

            uint256 accountedIndex;

            if (rewardIndexInitialized[reserveId][rewardToken]) {
                accountedIndex =
                    claimedRewardIndex[reserveId][rewardToken];
            } else {
                accountedIndex =
                    _rewardIndexBefore(
                        rewardToken,
                        eligibleAt
                    );
            }

            if (currentIndex <= accountedIndex) continue;

            uint256 amount =
                (CP_PER_RESERVE *
                    (currentIndex - accountedIndex)) /
                REWARD_PRECISION;

            if (amount == 0) continue;

            rewardIndexInitialized[reserveId][rewardToken] = true;
            claimedRewardIndex[reserveId][rewardToken] = currentIndex;

            rewardLiability[rewardToken] -= amount;
            totalRewardsClaimed[rewardToken] += amount;

            IERC20(rewardToken).safeTransfer(
                msg.sender,
                amount
            );

            _assertSolvent(rewardToken);

            emit RewardClaimed(
                reserveId,
                msg.sender,
                rewardToken,
                amount,
                currentIndex
            );

            unchecked {
                ++claimedTokenTypes;
            }
        }

        if (claimedTokenTypes == 0) revert NoReward();
    }

    function _createDistribution(
        address rewardToken,
        uint256 amount,
        uint256 eligibleCP,
        bytes32 reason
    ) internal {
        uint256 rewardPerCP =
            (amount * REWARD_PRECISION) / eligibleCP;

        uint256 distributedByIndex =
            (rewardPerCP * eligibleCP) / REWARD_PRECISION;

        uint256 dust =
            amount - distributedByIndex;

        rewardDust[rewardToken] += dust;
        rewardLiability[rewardToken] += distributedByIndex;

        uint256 cumulativeIndex =
            globalRewardIndex[rewardToken] + rewardPerCP;

        globalRewardIndex[rewardToken] = cumulativeIndex;

        uint256 id = ++distributionCount[rewardToken];
        uint256 sequence = ++globalDistributionSequence;

        distributions[rewardToken][id] = Distribution({
            timestamp: uint64(block.timestamp),
            amount: amount,
            eligibleCP: eligibleCP,
            rewardPerCP: rewardPerCP,
            cumulativeIndex: cumulativeIndex,
            globalSequence: sequence
        });

        totalDistributedRewards[rewardToken] += amount;

        emit RewardDistributed(
            rewardToken,
            id,
            amount,
            eligibleCP,
            rewardPerCP,
            cumulativeIndex,
            sequence,
            block.timestamp,
            reason
        );
    }

    /**
     * @dev Returns the cumulative reward index immediately BEFORE eligibleAt.
     *
     * Distribution IDs are chronological. Binary search makes first-time
     * initialization O(log N), while preserving the 24-hour anti-retroactive
     * rule. Distributions with timestamp == eligibleAt are intentionally NOT
     * included in the baseline and therefore remain claimable.
     */
    /**
     * @dev Returns the latest cumulative index whose global sequence is not
     * greater than maxSequence. Used after a reserve closes so it can claim
     * historical rewards but never future rewards.
     */
    function _rewardIndexAtSequence(
        address rewardToken,
        uint256 maxSequence
    ) internal view returns (uint256) {
        uint256 count = distributionCount[rewardToken];
        if (count == 0 || maxSequence == 0) return 0;

        uint256 low = 1;
        uint256 high = count;
        uint256 answer;

        while (low <= high) {
            uint256 mid = low + ((high - low) >> 1);
            Distribution storage d =
                distributions[rewardToken][mid];

            if (d.globalSequence <= maxSequence) {
                answer = d.cumulativeIndex;
                low = mid + 1;
            } else {
                if (mid == 1) break;
                high = mid - 1;
            }
        }

        return answer;
    }

    function _claimableCurrentIndex(
        uint256 reserveId,
        address rewardToken
    ) internal view returns (uint256) {
        uint256 endSequence = rewardEndSequence[reserveId];

        if (endSequence == 0) {
            return globalRewardIndex[rewardToken];
        }

        return _rewardIndexAtSequence(
            rewardToken,
            endSequence
        );
    }

    function _rewardIndexBefore(
        address rewardToken,
        uint256 eligibleAt
    ) internal view returns (uint256) {
        uint256 count = distributionCount[rewardToken];
        if (count == 0) return 0;

        uint256 low = 1;
        uint256 high = count;
        uint256 answer;

        while (low <= high) {
            uint256 mid = low + ((high - low) >> 1);
            Distribution storage d =
                distributions[rewardToken][mid];

            if (uint256(d.timestamp) < eligibleAt) {
                answer = d.cumulativeIndex;
                low = mid + 1;
            } else {
                if (mid == 1) break;
                high = mid - 1;
            }
        }

        return answer;
    }

    /**
     * @dev Advances the chronological eligibility cursor.
     *
     * Each reserve ID is processed at most once for eligibility. Because
     * reserve IDs are created in timestamp order, processing stops as soon
     * as the next live reserve has not yet reached 24 hours.
     *
     * Reserves that exited/completed before eligibility are skipped.
     *
     * Cost is amortized O(number of newly matured reserves), not O(total
     * historical reserves) for every reward distribution.
     */
    function _syncEligibleCP(uint256 maxSteps)
        internal
        returns (uint256 processed)
    {
        if (maxSteps == 0) revert SyncLimitZero();

        uint256 cursor = eligibilityCursor;
        uint256 upper = nextReserveId;

        while (cursor < upper && processed < maxSteps) {
            if (eligibilityProcessed[cursor]) {
                unchecked {
                    ++cursor;
                    ++processed;
                }
                continue;
            }

            Reserve memory r = reserves[cursor];

            if (r.token == address(0)) {
                eligibilityProcessed[cursor] = true;
                unchecked {
                    ++cursor;
                    ++processed;
                }
                continue;
            }

            uint256 eligibleAt =
                uint256(r.createdAt) + ELIGIBILITY_DELAY;

            if (block.timestamp < eligibleAt) {
                break;
            }

            eligibilityProcessed[cursor] = true;
            reserveEligible[cursor] = true;
            totalEligibleCP += CP_PER_RESERVE;

            emit EligibilityActivated(
                cursor,
                eligibleAt,
                totalEligibleCP
            );

            unchecked {
                ++cursor;
                ++processed;
            }
        }

        eligibilityCursor = cursor;
    }

    /**
     * @notice Permissionless bounded eligibility keeper.
     * @dev Call repeatedly if synced=false.
     */
    function syncEligibleCP(uint256 maxSteps)
        external
        returns (
            uint256 processed,
            bool synced,
            uint256 cursor
        )
    {
        processed = _syncEligibleCP(maxSteps);
        synced = _eligibilitySyncedNow();
        cursor = eligibilityCursor;
    }

    function _eligibilitySyncedNow()
        internal
        view
        returns (bool)
    {
        uint256 cursor = eligibilityCursor;

        while (
            cursor < nextReserveId &&
            eligibilityProcessed[cursor]
        ) {
            unchecked { ++cursor; }
        }

        if (cursor >= nextReserveId) return true;

        Reserve memory r = reserves[cursor];

        // Deleted positions can be advanced by the keeper.
        if (r.token == address(0)) return false;

        return
            block.timestamp <
            uint256(r.createdAt) + ELIGIBILITY_DELAY;
    }

    /**
     * @notice Returns stored eligible CP plus a view-only preview of reserve
     * IDs that have matured but have not yet been checkpointed.
     *
     * State-changing reward functions call _syncEligibleCP() first.
     */
    function currentEligibleCP() external view returns (uint256 eligibleCP) {
        eligibleCP = totalEligibleCP;

        uint256 cursor = eligibilityCursor;
        uint256 upper = nextReserveId;

        while (cursor < upper) {
            if (eligibilityProcessed[cursor]) {
                unchecked { ++cursor; }
                continue;
            }

            Reserve memory r = reserves[cursor];

            if (r.token == address(0)) {
                unchecked { ++cursor; }
                continue;
            }

            if (
                block.timestamp <
                uint256(r.createdAt) + ELIGIBILITY_DELAY
            ) {
                break;
            }

            eligibleCP += CP_PER_RESERVE;
            unchecked { ++cursor; }
        }
    }

    function _deactivateReserve(uint256 reserveId,Reserve memory r) internal {
        TokenConfig storage cfg = tokenConfig[r.token];
        if (cfg.activeReserves != 0) cfg.activeReserves--;

        activeReserveCount--;
        totalActiveCP -= CP_PER_RESERVE;

        // If this reserve had entered the eligible checkpoint, remove its
        // weight before any subsequent distribution snapshot.
        if (reserveEligible[reserveId]) {
            reserveEligible[reserveId] = false;
            totalEligibleCP -= CP_PER_RESERVE;
        }

        delete reserves[reserveId];
        _burn(reserveId);
    }

    /**
     * @dev Before maturity the NFT is non-transferable.
     * After 369 days it is transferable, but transfer DOES NOT close or
     * deactivate the reserve. The position remains in totalActiveCP and,
     * once eligible, totalEligibleCP. Future reward rights follow the NFT
     * because rewardOwner is updated to the new owner.
     */
    function _update(address to,uint256 tokenId,address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            Reserve memory r = reserves[tokenId];
            if (r.token == address(0)) revert InvalidReserve();
            if (block.timestamp < r.unlockTime)
                revert TransferBlocked();

            rewardOwner[tokenId] = to;
        }
        return super._update(to,tokenId,auth);
    }

    function isTokenRegistered(address token) external view returns (bool) {
        return tokenConfig[token].registered;
    }

    function registeredTokenCount() external view returns (uint256) {
        return registeredTokens.length;
    }

    function registeredTokenAt(uint256 index) external view returns (address) {
        return registeredTokens[index];
    }

    /**
     * @notice Returns the live lifecycle state of a reserve.
     * @dev A reserve can be matured and still active/reward-participating.
     */
    /**
     * @notice Solvency report for one registered token.
     *
     * requiredBalance = active reserve principal + unpaid claimable rewards.
     * Dust is deliberately excluded from liabilities because it was not
     * assigned through the integer reward-per-CP index.
     */
    function solvencyOf(address token)
        public
        view
        returns (
            uint256 balance,
            uint256 principal,
            uint256 rewards,
            uint256 dust,
            uint256 requiredBalance,
            uint256 surplus,
            bool solvent
        )
    {
        balance = IERC20(token).balanceOf(address(this));
        principal = principalLiability[token];
        rewards = rewardLiability[token];
        dust = rewardDust[token];

        requiredBalance = principal + rewards;
        solvent = balance >= requiredBalance;

        if (solvent) {
            surplus = balance - requiredBalance;
        }
    }

    function _assertSolvent(address token)
        internal
        view
    {
        uint256 requiredBalance =
            principalLiability[token] +
            rewardLiability[token];

        if (
            IERC20(token).balanceOf(address(this)) <
            requiredBalance
        ) {
            revert InsolventToken(token);
        }
    }

    /**
     * @notice Current address entitled to control reward claims.
     * While live, ERC721 ownership is authoritative. After burn/closure,
     * rewardOwner preserves the final owner's historical claim rights.
     */
    function rewardBeneficiary(uint256 reserveId)
        external
        view
        returns (address)
    {
        address liveOwner = _ownerOf(reserveId);
        return
            liveOwner != address(0)
                ? liveOwner
                : rewardOwner[reserveId];
    }

    function reserveStatus(uint256 reserveId)
        external
        view
        returns (
            bool active,
            bool matured,
            bool transferable,
            bool rewardEligible,
            uint256 cp
        )
    {
        Reserve memory r = reserves[reserveId];

        active = r.token != address(0);

        if (!active) {
            return (false, false, false, false, 0);
        }

        matured = block.timestamp >= uint256(r.unlockTime);
        transferable = matured;

        rewardEligible =
            block.timestamp >= rewardEligibleAt[reserveId];

        cp = rewardEligible ? CP_PER_RESERVE : 0;
    }

    function getReserve(uint256 reserveId) external view returns (
        address token,uint256 amount,uint256 cp,uint256 createdAt,
        uint256 eligibleAt,uint256 unlockTime,uint256 rawAmount,bool rewardEligible
    ) {
        Reserve memory r = reserves[reserveId];
        if (r.token == address(0)) revert InvalidReserve();
        return (
            r.token,
            RESERVE_AMOUNT,
            CP_PER_RESERVE,
            r.createdAt,
            uint256(r.createdAt) + ELIGIBILITY_DELAY,
            r.unlockTime,
            r.rawAmount,
            block.timestamp >= uint256(r.createdAt) + ELIGIBILITY_DELAY
        );
    }

    function getDistribution(address rewardToken,uint256 distributionId) external view returns (Distribution memory) {
        return distributions[rewardToken][distributionId];
    }

    function version() external pure returns (string memory) {
        return "FUSEReserve";
    }

    /**
     * @notice Permanent protocol provenance for a FUSEReserve position.
     * The card may visually emphasize MINTer branding, while the immutable
     * metadata identifies the position specifically as a FUSEr.
     */
    function protocolProvenance(uint256 reserveId)
        external
        view
        returns (
            string memory brand,
            string memory fuseIdentity,
            uint256 chainId,
            address tokenContract,
            bytes32 positionIdentityHash
        )
    {
        bytes32 pid =
            reserveCustomization[reserveId].positionIdentityHash;
        if (pid == bytes32(0)) revert InvalidReserve();

        address token = positionToken[reserveId];
        if (token == address(0)) revert InvalidReserve();

        return (
            PROTOCOL_BRAND,
            FUSER_IDENTITY,
            PULSECHAIN_CHAIN_ID,
            token,
            pid
        );
    }

    /**
     * @notice Verifies the immutable on-chain identity registered for a token.
     * This binds the displayed token identity to PulseChain (369) and the
     * exact ERC20 contract address that supplied name/symbol/decimals.
     */
    function verifyTokenIdentity(address token)
        external
        view
        returns (
            bool valid,
            uint256 chainId,
            address tokenContract,
            string memory name,
            string memory symbol,
            uint8 decimals,
            bytes32 identityHash
        )
    {
        TokenConfig storage cfg = tokenConfig[token];
        TokenIdentity storage ti = tokenIdentity[token];

        if (!cfg.registered) {
            return (
                false,
                PULSECHAIN_CHAIN_ID,
                token,
                "",
                "",
                0,
                bytes32(0)
            );
        }

        bytes32 expectedHash = keccak256(
            abi.encode(
                PULSECHAIN_CHAIN_ID,
                token,
                ti.name,
                ti.symbol,
                cfg.decimals,
                ti.logoHash
            )
        );

        valid =
            ti.chainId == PULSECHAIN_CHAIN_ID &&
            ti.tokenContract == token &&
            ti.tokenIdentityHash == expectedHash;

        return (
            valid,
            ti.chainId,
            ti.tokenContract,
            ti.name,
            ti.symbol,
            cfg.decimals,
            ti.tokenIdentityHash
        );
    }

    /**
     * @notice Immutable FUSE position identity.
     * The customization is written only during mint and is never editable.
     */
    function positionIdentity(uint256 reserveId)
        external
        view
        returns (bytes32)
    {
        bytes32 id =
            reserveCustomization[reserveId].positionIdentityHash;
        if (id == bytes32(0)) revert InvalidReserve();
        return id;
    }

    /**
     * @notice On-chain JSON metadata. The image itself is referenced by the
     * token's registered logoURI and committed by logoHash. The contract
     * cannot fetch off-chain media, so the dApp/indexer must verify that the
     * retrieved logo bytes match logoHash.
     *
     * Name + ticker are mandatory protocol identity fields and cannot be
     * customized away by the NFT creator.
     */
    /**
     * @notice Compact deterministic metadata endpoint.
     * @dev All economic, customization, token identity and provenance data
     *      remains stored and independently readable on-chain. The dApp/indexer
     *      renders the full NFT card from those canonical fields.
     */
    function tokenURI(uint256 reserveId)
        public
        view
        override
        returns (string memory)
    {
        if (_ownerOf(reserveId) == address(0)) revert InvalidReserve();
        if (reserveCustomization[reserveId].positionIdentityHash == bytes32(0))
            revert InvalidReserve();

        return string.concat(
            "https://minter.finance/api/fusereserve/metadata/",
            _uintToString(reserveId)
        );
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            unchecked { ++digits; }
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            unchecked { --digits; }
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }

    function _readName(address token)
        internal
        view
        returns (string memory)
    {
        try IERC20Metadata(token).name()
            returns (string memory n)
        {
            return n;
        } catch {
            revert InvalidToken();
        }
    }

    function _readSymbol(address token)
        internal
        view
        returns (string memory)
    {
        try IERC20Metadata(token).symbol()
            returns (string memory sym)
        {
            return sym;
        } catch {
            revert InvalidToken();
        }
    }

    function _readTotalSupply(address token)
        internal
        view
        returns (uint256 supply)
    {
        (bool ok, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        if (!ok || data.length < 32) revert InvalidToken();
        supply = abi.decode(data, (uint256));
    }

    function _readDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            if (d > 18) revert InvalidTokenDecimals();
            return d;
        } catch {
            revert InvalidTokenDecimals();
        }
    }
}
