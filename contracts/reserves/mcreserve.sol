// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC721/ERC721.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/IERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/Base64.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/Strings.sol";

contract MINTCOINReserve is ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    IERC20 public immutable mintcoin;

    address public constant MINTCOIN_ADDRESS =
        0x2ba46688cA3D83cBfe7a5e1572Fc55EE724651f2;

    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public constant MINTER_ADDRESS =
        0x2c25a1080078D0C6Fc1e5a81683573975Cfd65c8;

    uint256 public constant BPS = 10_000;
    uint256 public constant PENALTY_BPS = 5_000;

    uint256 public constant REWARD_POOL_BPS = 4_000;
    uint256 public constant BURN_BPS = 500;
    uint256 public constant MINTER_BPS = 500;

    uint256 public constant REWARD_COOLDOWN = 24 hours;
    uint256 public constant REWARD_PRECISION = 1e36;

    uint256 public constant SPARK = 10_000;
    uint256 public constant EMBER = 11_500;
    uint256 public constant FLAME = 13_500;
    uint256 public constant BLAZE = 17_500;
    uint256 public constant FORGE = 25_000;
    uint256 public constant PILLAR = 35_000;
    uint256 public constant ETERNAL = 100_000;

    error InvalidAmountTier();
    error InvalidDurationTier();
    error NotOwner();
    error StillLocked();
    error TransferBlocked();
    error RewardNotReady();
    error NoReward();

    struct Reserve {
        uint128 amount;
        uint128 ce;
        uint64 createdAt;
        uint64 unlockTime;
        uint32 durationDays;
        uint16 amountTier;
        uint16 durationTier;
        uint256 proofId;
    }

    /*
        INTERNAL PROOF OF CONVICTION

        This is NOT a separate token.

        It exists only as an on-chain identity derived
        from the originating Reserve NFT.

        Relationship:

        Reserve NFT -> CE -> Proof
    */
    struct Proof {
        uint256 reserveId;
        uint256 ce;
        uint16 amountTier;
        uint16 durationTier;
    }

    struct Distribution {
        uint256 amount;
        uint256 activeCE;
        uint256 createdAt;
        uint256 claimableAt;
        uint256 rewardPerCE;
    }

    mapping(uint256 => Reserve) public reserves;
    mapping(uint256 => Proof) public proofs;

    mapping(uint256 => uint256) public reserveToProof;
    mapping(uint256 => address) private proofOwner;

    uint256 public nextReserveId = 1;
    uint256 public nextProofId = 1;

    uint256 public totalLocked;
    uint256 public totalCE;
    uint256 public totalBurned;
    uint256 public totalRewardPool;
    uint256 public totalRewardsClaimed;

    uint256 public nextDistributionId = 1;

    mapping(uint256 => Distribution) public distributions;
    mapping(uint256 => uint256) public rewardCursor;
    mapping(uint256 => uint256) public pendingRewards;

    mapping(address => uint256) public closedReserveRewards;
    mapping(address => uint256) public closedReserveRewardClaimableAt;

    event ReserveCreated(
        uint256 indexed reserveId,
        address indexed owner,
        uint256 amount,
        uint256 ce,
        uint256 proofId
    );

    event ProofCreated(
        uint256 indexed proofId,
        uint256 indexed reserveId,
        uint256 ce
    );

    event IdentitySynced(
        uint256 indexed reserveId,
        uint256 indexed proofId,
        address indexed owner
    );

    event ReserveCompleted(
        uint256 indexed reserveId,
        address indexed owner
    );

    event ReserveBroken(
        uint256 indexed reserveId,
        uint256 burned
    );

    event RewardDistributionCreated(
        uint256 indexed distributionId,
        uint256 indexed reserveId,
        uint256 amount,
        uint256 activeCE,
        uint256 claimableAt
    );

    event RewardClaimed(
        uint256 indexed reserveId,
        address indexed owner,
        uint256 amount
    );

    event ClosedReserveRewardClaimed(
        address indexed owner,
        uint256 amount
    );

    constructor()
        ERC721("MINTCOIN Conviction Reserve", "MCRESERVE")
    {
        mintcoin = IERC20(MINTCOIN_ADDRESS);
    }

    // =====================================================
    // RESERVE
    // =====================================================

    function buildReserve(
        uint256 amount,
        uint256 durationDays
    )
        external
        nonReentrant
        returns (uint256 reserveId)
    {
        uint16 amountTier = _amountTier(amount);
        uint16 durationTier = _durationTier(durationDays);

        uint256 ce =
            amount *
            durationDays *
            _multiplier(durationTier) /
            BPS;

        mintcoin.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        reserveId = nextReserveId++;

        uint256 proofId = nextProofId++;

        reserves[reserveId] = Reserve({
            amount: uint128(amount),
            ce: uint128(ce),
            createdAt: uint64(block.timestamp),
            unlockTime: uint64(
                block.timestamp + durationDays * 1 days
            ),
            durationDays: uint32(durationDays),
            amountTier: amountTier,
            durationTier: durationTier,
            proofId: proofId
        });

        proofs[proofId] = Proof({
            reserveId: reserveId,
            ce: ce,
            amountTier: amountTier,
            durationTier: durationTier
        });

        reserveToProof[reserveId] = proofId;
        rewardCursor[reserveId] = nextDistributionId;

        totalLocked += amount;
        totalCE += ce;

        _safeMint(msg.sender, reserveId);

        proofOwner[proofId] = msg.sender;

        emit ProofCreated(proofId, reserveId, ce);
        emit IdentitySynced(reserveId, proofId, msg.sender);

        emit ReserveCreated(
            reserveId,
            msg.sender,
            amount,
            ce,
            proofId
        );
    }

    // =====================================================
    // INTERNAL PROOF
    // =====================================================

    function proofOwnerOf(
        uint256 proofId
    )
        external
        view
        returns (address)
    {
        return proofOwner[proofId];
    }

    function getReserveIdentity(
        uint256 reserveId
    )
        external
        view
        returns (
            uint256 ce,
            uint256 proofId,
            uint16 amountTier,
            uint16 durationTier
        )
    {
        Reserve memory r = reserves[reserveId];

        return (
            r.ce,
            r.proofId,
            r.amountTier,
            r.durationTier
        );
    }

    function getProofIdentity(
        uint256 proofId
    )
        external
        view
        returns (
            uint256 reserveId,
            uint256 ce,
            uint16 amountTier,
            uint16 durationTier,
            address owner
        )
    {
        Proof memory p = proofs[proofId];

        return (
            p.reserveId,
            p.ce,
            p.amountTier,
            p.durationTier,
            proofOwner[proofId]
        );
    }

    // =====================================================
    // CE
    // =====================================================

    function calculateCE(
        uint256 amount,
        uint256 durationDays
    )
        external
        pure
        returns (uint256)
    {
        uint16 tier = _durationTier(durationDays);

        return
            amount *
            durationDays *
            _multiplier(tier) /
            BPS;
    }

    function _multiplier(
        uint16 tier
    )
        internal
        pure
        returns (uint256)
    {
        if (tier == 0) return SPARK;
        if (tier == 1) return EMBER;
        if (tier == 2) return FLAME;
        if (tier == 3) return BLAZE;
        if (tier == 4) return FORGE;
        if (tier == 5) return PILLAR;
        return ETERNAL;
    }

    function _amountTier(
        uint256 amount
    )
        internal
        pure
        returns (uint16)
    {
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

    function _durationTier(
        uint256 daysLocked
    )
        internal
        pure
        returns (uint16)
    {
        if (daysLocked == 60) return 0;
        if (daysLocked == 90) return 1;
        if (daysLocked == 120) return 2;
        if (daysLocked == 180) return 3;
        if (daysLocked == 360) return 4;
        if (daysLocked == 555) return 5;
        if (daysLocked == 5555) return 6;

        revert InvalidDurationTier();
    }

    // =====================================================
    // REWARDS
    // =====================================================

    function _accrue(
        uint256 reserveId
    )
        internal
    {
        Reserve memory r = reserves[reserveId];
        uint256 cursor = rewardCursor[reserveId];

        while (cursor < nextDistributionId) {
            Distribution memory d = distributions[cursor];

            if (block.timestamp < d.claimableAt)
                break;

            pendingRewards[reserveId] +=
                uint256(r.ce) *
                d.rewardPerCE /
                REWARD_PRECISION;

            unchecked {
                ++cursor;
            }
        }

        rewardCursor[reserveId] = cursor;
    }

    function pendingReward(
        uint256 reserveId
    )
        public
        view
        returns (uint256 total)
    {
        Reserve memory r = reserves[reserveId];
        uint256 cursor = rewardCursor[reserveId];

        total = pendingRewards[reserveId];

        while (cursor < nextDistributionId) {
            Distribution memory d = distributions[cursor];

            if (block.timestamp < d.claimableAt)
                break;

            total +=
                uint256(r.ce) *
                d.rewardPerCE /
                REWARD_PRECISION;

            unchecked {
                ++cursor;
            }
        }
    }

    /*
        IMPORTANT:

        This function intentionally does NOT require
        the Reserve to be unlocked.

        Rewards may be claimed before the Reserve ends.
    */
    function claimReward(
        uint256 reserveId
    )
        external
        nonReentrant
        returns (uint256 amount)
    {
        if (ownerOf(reserveId) != msg.sender)
            revert NotOwner();

        _accrue(reserveId);

        amount = pendingRewards[reserveId];

        if (amount == 0)
            revert NoReward();

        pendingRewards[reserveId] = 0;
        totalRewardsClaimed += amount;

        mintcoin.safeTransfer(msg.sender, amount);

        emit RewardClaimed(
            reserveId,
            msg.sender,
            amount
        );
    }

    function claimableAt(
        uint256 distributionId
    )
        external
        view
        returns (uint256)
    {
        return distributions[distributionId].claimableAt;
    }

    function getRewardDistribution(
        uint256 distributionId
    )
        external
        view
        returns (
            uint256 amount,
            uint256 activeCE,
            uint256 createdAt,
            uint256 claimableAt_,
            uint256 rewardPerCE
        )
    {
        Distribution memory d =
            distributions[distributionId];

        return (
            d.amount,
            d.activeCE,
            d.createdAt,
            d.claimableAt,
            d.rewardPerCE
        );
    }

    // =====================================================
    // NFT / INTERNAL PROOF SYNC
    // =====================================================

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);

        /*
            Reserve NFT cannot move while locked.

            Once unlocked, its internal Proof identity
            follows the NFT owner.
        */
        if (from != address(0) && to != address(0)) {
            Reserve memory r = reserves[tokenId];

            if (block.timestamp < r.unlockTime)
                revert TransferBlocked();

            _accrue(tokenId);

            proofOwner[r.proofId] = to;

            emit IdentitySynced(
                tokenId,
                r.proofId,
                to
            );
        }

        return super._update(to, tokenId, auth);
    }

    /*
        No external Proof/SBT transfer exists.

        The Proof belongs conceptually to its Reserve NFT.
    */
    function transferProof(
        uint256,
        address
    )
        external
        pure
    {
        revert TransferBlocked();
    }

    // =====================================================
    // REWARD PRESERVATION
    // =====================================================

    function _preserveFutureRewards(
        uint256 reserveId,
        address account,
        uint256 ce
    )
        internal
    {
        uint256 cursor = rewardCursor[reserveId];
        uint256 future;
        uint256 latest;

        while (cursor < nextDistributionId) {
            Distribution memory d = distributions[cursor];

            if (block.timestamp < d.claimableAt) {
                future +=
                    ce *
                    d.rewardPerCE /
                    REWARD_PRECISION;

                if (d.claimableAt > latest)
                    latest = d.claimableAt;
            }

            unchecked {
                ++cursor;
            }
        }

        if (future > 0) {
            closedReserveRewards[account] += future;

            if (
                latest >
                closedReserveRewardClaimableAt[account]
            ) {
                closedReserveRewardClaimableAt[account] =
                    latest;
            }
        }
    }

    // =====================================================
    // COMPLETE RESERVE
    // =====================================================

    function completeReserve(
        uint256 reserveId
    )
        external
        nonReentrant
    {
        if (ownerOf(reserveId) != msg.sender)
            revert NotOwner();

        Reserve memory r = reserves[reserveId];

        if (block.timestamp < r.unlockTime)
            revert StillLocked();

        _accrue(reserveId);

        uint256 matured = pendingRewards[reserveId];

        if (matured > 0) {
            pendingRewards[reserveId] = 0;
            totalRewardsClaimed += matured;

            mintcoin.safeTransfer(
                msg.sender,
                matured
            );

            emit RewardClaimed(
                reserveId,
                msg.sender,
                matured
            );
        }

        _preserveFutureRewards(
            reserveId,
            msg.sender,
            r.ce
        );

        _removeReserve(reserveId, r);

        mintcoin.safeTransfer(
            msg.sender,
            r.amount
        );

        emit ReserveCompleted(
            reserveId,
            msg.sender
        );
    }

    // =====================================================
    // EARLY EXIT
    // =====================================================

    function emergencyExit(
        uint256 reserveId
    )
        external
        nonReentrant
    {
        if (ownerOf(reserveId) != msg.sender)
            revert NotOwner();

        Reserve memory r = reserves[reserveId];

        if (block.timestamp >= r.unlockTime)
            revert StillLocked();

        /*
            Pay rewards that have already cooled down.
        */
        _accrue(reserveId);

        uint256 matured = pendingRewards[reserveId];

        if (matured > 0) {
            pendingRewards[reserveId] = 0;
            totalRewardsClaimed += matured;

            mintcoin.safeTransfer(
                msg.sender,
                matured
            );

            emit RewardClaimed(
                reserveId,
                msg.sender,
                matured
            );
        }

        /*
            Preserve rewards still cooling.
        */
        _preserveFutureRewards(
            reserveId,
            msg.sender,
            r.ce
        );

        /*
            Remove this Reserve from active CE BEFORE
            calculating the new reward distribution.
        */
        totalLocked -= r.amount;
        totalCE -= r.ce;

        /*
            40% -> Reward Pool
             5% -> Burn
             5% -> MINTER
            50% -> User
        */
        uint256 rewardAmount =
            r.amount *
            REWARD_POOL_BPS /
            BPS;

        uint256 burnAmount =
            r.amount *
            BURN_BPS /
            BPS;

        uint256 treasuryAmount =
            r.amount *
            MINTER_BPS /
            BPS;

        uint256 distributionId =
            nextDistributionId++;

        uint256 rewardPerCE;

        if (totalCE > 0) {
            rewardPerCE =
                rewardAmount *
                REWARD_PRECISION /
                totalCE;
        }

        distributions[distributionId] =
            Distribution({
                amount: rewardAmount,
                activeCE: totalCE,
                createdAt: block.timestamp,
                claimableAt:
                    block.timestamp +
                    REWARD_COOLDOWN,
                rewardPerCE: rewardPerCE
            });

        totalRewardPool += rewardAmount;

        emit RewardDistributionCreated(
            distributionId,
            reserveId,
            rewardAmount,
            totalCE,
            block.timestamp + REWARD_COOLDOWN
        );

        mintcoin.safeTransfer(
            BURN_ADDRESS,
            burnAmount
        );

        totalBurned += burnAmount;

        mintcoin.safeTransfer(
            MINTER_ADDRESS,
            treasuryAmount
        );

        uint256 proofId = r.proofId;

        delete reserves[reserveId];
        delete proofs[proofId];
        delete reserveToProof[reserveId];
        delete proofOwner[proofId];
        delete rewardCursor[reserveId];
        delete pendingRewards[reserveId];

        _burn(reserveId);

        uint256 returned =
            r.amount *
            (BPS - PENALTY_BPS) /
            BPS;

        mintcoin.safeTransfer(
            msg.sender,
            returned
        );

        emit ReserveBroken(
            reserveId,
            burnAmount
        );
    }

    // =====================================================
    // INTERNAL REMOVE
    // =====================================================

    function _removeReserve(
        uint256 reserveId,
        Reserve memory r
    )
        internal
    {
        totalLocked -= r.amount;
        totalCE -= r.ce;

        delete reserves[reserveId];
        delete proofs[r.proofId];
        delete reserveToProof[reserveId];
        delete proofOwner[r.proofId];
        delete rewardCursor[reserveId];
        delete pendingRewards[reserveId];

        _burn(reserveId);
    }

    // =====================================================
    // CLOSED REWARDS
    // =====================================================

    function claimClosedReserveRewards()
        external
        nonReentrant
        returns (uint256 amount)
    {
        if (
            block.timestamp <
            closedReserveRewardClaimableAt[msg.sender]
        )
            revert RewardNotReady();

        amount = closedReserveRewards[msg.sender];

        if (amount == 0)
            revert NoReward();

        closedReserveRewards[msg.sender] = 0;
        closedReserveRewardClaimableAt[msg.sender] = 0;

        totalRewardsClaimed += amount;

        mintcoin.safeTransfer(
            msg.sender,
            amount
        );

        emit ClosedReserveRewardClaimed(
            msg.sender,
            amount
        );
    }

    function closedReserveReward(
        address account
    )
        external
        view
        returns (
            uint256 amount,
            uint256 claimableAt_
        )
    {
        return (
            closedReserveRewards[account],
            closedReserveRewardClaimableAt[account]
        );
    }

    // =====================================================
    // VIEWS
    // =====================================================

    function totalActiveCE()
        external
        view
        returns (uint256)
    {
        return totalCE;
    }

    function rewardPoolBalance()
        external
        view
        returns (uint256)
    {
        uint256 balance =
            mintcoin.balanceOf(address(this));

        return balance > totalLocked
            ? balance - totalLocked
            : 0;
    }

    // =====================================================
    // METADATA
    // =====================================================

    function tokenURI(
        uint256 reserveId
    )
        public
        view
        override
        returns (string memory)
    {
        Reserve memory r = reserves[reserveId];

        string memory json = string(
            abi.encodePacked(
                '{"name":"MINTCOIN Conviction Reserve #',
                reserveId.toString(),
                '","description":"Locked MINTCOIN conviction position",',
                '"attributes":[',
                '{"trait_type":"CE","value":"',
                uint256(r.ce).toString(),
                '"},',
                '{"trait_type":"Amount Tier","value":"',
                uint256(r.amountTier).toString(),
                '"},',
                '{"trait_type":"Duration Tier","value":"',
                uint256(r.durationTier).toString(),
                '"},',
                '{"trait_type":"Proof ID","value":"',
                r.proofId.toString(),
                '"}]}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            )
        );
    }

    // =====================================================
    // VERSION / IDENTITY
    // =====================================================

    function version()
        external
        pure
        returns (string memory)
    {
        return "MINTCOIN Reserve";
    }
}
