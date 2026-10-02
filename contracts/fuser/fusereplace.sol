// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts@5.0.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts@5.0.2/utils/ReentrancyGuard.sol";
interface IFUSERewardSink {
    function injectReward(address rewardToken, uint256 amount) external;
}
interface IFUSEReserveMarket is IERC721, IFUSERewardSink {
    function reserveStatus(uint256 reserveId)
        external
        view
        returns (
            bool active,
            bool matured,
            bool transferable,
            bool rewardEligible,
            uint256 cp
        );
    function syncEligibleCP(uint256 maxSteps)
        external
        returns (uint256 processed, bool synced, uint256 cursor);
}
interface IFUSEReactorMarket is IERC721, IFUSERewardSink {
    function positionStatus(uint256 positionId)
        external
        view
        returns (
            bool active,
            bool cooling,
            bool earning,
            bool matured,
            bool transferable,
            uint256 principal,
            uint256 cp,
            uint256 eligibleAt,
            uint256 unlockTime
        );
    function syncEligibility(uint256 maxSteps) external;
    function eligibilitySyncRequired() external view returns (bool);
    function eligibilitySyncState()
        external
        view
        returns (
            uint256 cursor,
            uint256 queueLength,
            bool syncRequired
        );
}
/// @title FUSEReplace
/// @author MINTer
/// @notice Secondary marketplace for mature FUSEReserve and FUSEReactor NFTs on PulseChain.
/// @dev Developed by MINTer. FUSEReplace never custodies underlying position principal and never pre-custodies NFTs.
contract FUSEReplace is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant PULSECHAIN_ID = 369;
    address public constant CV_ADDRESS =
        0x83c8b596B0825326707F5BC88E2bd2a052d3FfBa;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    IERC20 public constant CV = IERC20(CV_ADDRESS);
    IERC20 public constant DAI = IERC20(DAI_ADDRESS);
    uint256 public constant ACTIVITY_FEE_CV = 369 ether;
    uint256 public constant BPS = 10_000;
    uint256 public constant SELLER_BPS = 9_700;
    uint256 public constant FUSERESERVE_BPS = 100;
    uint256 public constant FUSEREACTOR_BPS = 200;
    uint256 public constant DURATION_24_HOURS = 1 days;
    uint256 public constant DURATION_7_DAYS = 7 days;
    uint256 public constant DURATION_30_DAYS = 30 days;
    IFUSEReserveMarket public immutable FUSEReserve;
    IFUSEReactorMarket public immutable FUSEReactor;
    enum PositionSource {
        FUSEReserve,
        FUSEReactor
    }
    enum ListingStatus {
        NONE,
        ACTIVE,
        SOLD,
        CANCELLED,
        EXPIRED
    }
    enum OfferStatus {
        NONE,
        ACTIVE,
        ACCEPTED,
        CANCELLED
    }
    struct Listing {
        uint256 listingId;
        PositionSource source;
        uint256 positionId;
        address seller;
        uint256 priceDAI;
        uint64 createdAt;
        uint64 expiresAt;
        uint64 nonce;
        ListingStatus status;
    }
    struct Offer {
        uint256 offerId;
        uint256 listingId;
        PositionSource source;
        uint256 positionId;
        address buyer;
        address expectedSeller;
        uint256 amountDAI;
        uint64 listingNonce;
        uint64 createdAt;
        OfferStatus status;
    }
    uint256 public nextListingId = 1;
    uint256 public nextOfferId = 1;
    uint256 public totalOfferEscrow;
    uint256 public pendingFUSEReserveDAI;
    uint256 public pendingFUSEReactorDAI;
    uint256 public pendingFUSEReserveCV;
    uint256 public pendingFUSEReactorCV;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;
    mapping(bytes32 => uint64) public positionListingNonce;
    mapping(bytes32 => uint256) public activeListingForPosition;
    error WrongChain();
    error ZeroAddress();
    error InvalidContract();
    error InvalidDuration();
    error ZeroPrice();
    error ZeroOffer();
    error NotPositionOwner();
    error PositionNotActive();
    error PositionNotMature();
    error PositionNotTransferable();
    error ListingNotActive();
    error ListingExpired();
    error ListingNotExpired();
    error NotListingSeller();
    error SelfPurchaseForbidden();
    error SelfOfferForbidden();
    error MarketplaceNotApproved();
    error ActiveListingExists();
    error OfferNotActive();
    error NotOfferBuyer();
    error NotExpectedSeller();
    error OfferStillExecutable();
    error ListingInstanceMismatch();
    error EscrowInsolvent(uint256 balance, uint256 required);
    error ExactTransferRequired();
    event ListingCreated(
        uint256 indexed listingId,
        PositionSource indexed source,
        uint256 indexed positionId,
        address seller,
        uint256 priceDAI,
        uint256 expiresAt,
        uint64 nonce
    );
    event ListingPriceUpdated(
        uint256 indexed listingId,
        uint256 oldPriceDAI,
        uint256 newPriceDAI,
        uint256 cvInjectedToFUSEReserve
    );
    event ListingCancelled(
        uint256 indexed listingId,
        bool early,
        uint256 cvInjectedToFUSEReserve
    );
    event ListingExpiredMaterialized(uint256 indexed listingId);
    event ListingSold(
        uint256 indexed listingId,
        uint256 indexed positionId,
        PositionSource indexed source,
        address seller,
        address buyer,
        uint256 grossDAI,
        uint256 sellerDAI,
        uint256 fusereserveDAI,
        uint256 fusereactorDAI
    );
    event OfferCreated(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amountDAI,
        uint64 listingNonce,
        uint256 cvInjectedToFUSEReactor
    );
    event OfferCancelled(
        uint256 indexed offerId,
        address indexed buyer,
        uint256 refundedDAI
    );
    event OfferAccepted(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amountDAI
    );
    event InvalidatedOfferWithdrawn(
        uint256 indexed offerId,
        address indexed buyer,
        uint256 refundedDAI
    );
    event RewardAccrued(address indexed sink, address indexed token, uint256 amount);
    event RewardFlushed(address indexed sink, address indexed token, uint256 amount);
    constructor(address fusereserve_, address fusereactor_) {
        if (block.chainid != PULSECHAIN_ID) revert WrongChain();
        if (fusereserve_ == address(0) || fusereactor_ == address(0)) revert ZeroAddress();
        if (fusereserve_.code.length == 0 || fusereactor_.code.length == 0) {
            revert InvalidContract();
        }
        FUSEReserve = IFUSEReserveMarket(fusereserve_);
        FUSEReactor = IFUSEReactorMarket(fusereactor_);
    }
    // =============================================================
    // LISTINGS
    // =============================================================
    function listReserve(
        PositionSource source,
        uint256 positionId,
        uint256 priceDAI,
        uint256 duration
    ) external nonReentrant returns (uint256 listingId) {
        if (priceDAI == 0) revert ZeroPrice();
        if (!_validDuration(duration)) revert InvalidDuration();
        _validateTradablePosition(source, positionId, msg.sender);
        bytes32 key = _positionKey(source, positionId);
        uint256 previousId = activeListingForPosition[key];
        if (previousId != 0) {
            Listing storage previous = listings[previousId];
            if (
                previous.status == ListingStatus.ACTIVE &&
                block.timestamp <= previous.expiresAt &&
                _safeOwnerOf(source, positionId) == previous.seller
            ) {
                revert ActiveListingExists();
            }
            if (
                previous.status == ListingStatus.ACTIVE &&
                block.timestamp > previous.expiresAt
            ) {
                previous.status = ListingStatus.EXPIRED;
                emit ListingExpiredMaterialized(previousId);
            }
            activeListingForPosition[key] = 0;
        }
        uint64 nonce = ++positionListingNonce[key];
        listingId = nextListingId++;
        listings[listingId] = Listing({
            listingId: listingId,
            source: source,
            positionId: positionId,
            seller: msg.sender,
            priceDAI: priceDAI,
            createdAt: uint64(block.timestamp),
            expiresAt: uint64(block.timestamp + duration),
            nonce: nonce,
            status: ListingStatus.ACTIVE
        });
        activeListingForPosition[key] = listingId;
        emit ListingCreated(
            listingId,
            source,
            positionId,
            msg.sender,
            priceDAI,
            block.timestamp + duration,
            nonce
        );
    }
    function updatePrice(uint256 listingId, uint256 newPriceDAI) external nonReentrant {
        if (newPriceDAI == 0) revert ZeroPrice();
        Listing storage listing = listings[listingId];
        _requireLiveListing(listing);
        if (listing.seller != msg.sender) revert NotListingSeller();
        _validateTradablePosition(listing.source, listing.positionId, listing.seller);
        uint256 oldPrice = listing.priceDAI;
        listing.priceDAI = newPriceDAI;
        _collectAndAccrueCV(msg.sender, IFUSERewardSink(address(FUSEReserve)));
        emit ListingPriceUpdated(
            listingId,
            oldPrice,
            newPriceDAI,
            ACTIVITY_FEE_CV
        );
    }
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (listing.status != ListingStatus.ACTIVE) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotListingSeller();
        bytes32 key = _positionKey(listing.source, listing.positionId);
        if (block.timestamp > listing.expiresAt) {
            listing.status = ListingStatus.EXPIRED;
            if (activeListingForPosition[key] == listingId) {
                activeListingForPosition[key] = 0;
            }
            emit ListingExpiredMaterialized(listingId);
            emit ListingCancelled(listingId, false, 0);
            return;
        }
        listing.status = ListingStatus.CANCELLED;
        if (activeListingForPosition[key] == listingId) {
            activeListingForPosition[key] = 0;
        }
        _collectAndAccrueCV(msg.sender, IFUSERewardSink(address(FUSEReserve)));
        emit ListingCancelled(listingId, true, ACTIVITY_FEE_CV);
    }
    function materializeExpiration(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        if (listing.status != ListingStatus.ACTIVE) revert ListingNotActive();
        if (block.timestamp <= listing.expiresAt) revert ListingNotExpired();
        listing.status = ListingStatus.EXPIRED;
        bytes32 key = _positionKey(listing.source, listing.positionId);
        if (activeListingForPosition[key] == listingId) {
            activeListingForPosition[key] = 0;
        }
        emit ListingExpiredMaterialized(listingId);
    }
    // =============================================================
    // DIRECT BUY
    // =============================================================
    function buy(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        _requireExecutableListing(listing, msg.sender);
        uint256 gross = listing.priceDAI;
        address seller = listing.seller;
        PositionSource source = listing.source;
        uint256 positionId = listing.positionId;
        listing.status = ListingStatus.SOLD;
        bytes32 key = _positionKey(source, positionId);
        if (activeListingForPosition[key] == listingId) {
            activeListingForPosition[key] = 0;
        }
        _pullExact(DAI, msg.sender, gross);
        _settleSale(seller, gross);
        _nft(source).safeTransferFrom(seller, msg.sender, positionId);
        _assertEscrowSolvent();
        (
            uint256 sellerAmount,
            uint256 fusereserveAmount,
            uint256 fusereactorAmount
        ) = _saleAmounts(gross);
        emit ListingSold(
            listingId,
            positionId,
            source,
            seller,
            msg.sender,
            gross,
            sellerAmount,
            fusereserveAmount,
            fusereactorAmount
        );
    }
    // =============================================================
    // OFFERS
    // =============================================================
    function makeOffer(
        uint256 listingId,
        uint256 amountDAI
    ) external nonReentrant returns (uint256 offerId) {
        if (amountDAI == 0) revert ZeroOffer();
        Listing storage listing = listings[listingId];
        _requireLiveListing(listing);
        if (msg.sender == listing.seller) revert SelfOfferForbidden();
        _validateTradablePosition(listing.source, listing.positionId, listing.seller);
        offerId = nextOfferId++;
        offers[offerId] = Offer({
            offerId: offerId,
            listingId: listingId,
            source: listing.source,
            positionId: listing.positionId,
            buyer: msg.sender,
            expectedSeller: listing.seller,
            amountDAI: amountDAI,
            listingNonce: listing.nonce,
            createdAt: uint64(block.timestamp),
            status: OfferStatus.ACTIVE
        });
        totalOfferEscrow += amountDAI;
        _pullExact(DAI, msg.sender, amountDAI);
        _collectAndAccrueCV(msg.sender, IFUSERewardSink(address(FUSEReactor)));
        _assertEscrowSolvent();
        emit OfferCreated(
            offerId,
            listingId,
            msg.sender,
            amountDAI,
            listing.nonce,
            ACTIVITY_FEE_CV
        );
    }
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (offer.status != OfferStatus.ACTIVE) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert NotOfferBuyer();
        uint256 refund = offer.amountDAI;
        offer.status = OfferStatus.CANCELLED;
        totalOfferEscrow -= refund;
        DAI.safeTransfer(msg.sender, refund);
        _assertEscrowSolvent();
        emit OfferCancelled(offerId, msg.sender, refund);
    }
    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (offer.status != OfferStatus.ACTIVE) revert OfferNotActive();
        if (offer.expectedSeller != msg.sender) revert NotExpectedSeller();
        Listing storage listing = listings[offer.listingId];
        _requireLiveListing(listing);
        _requireSameListingInstance(listing, offer);
        if (listing.seller != msg.sender) revert NotExpectedSeller();
        _validateTradablePosition(listing.source, listing.positionId, msg.sender);
        _requireMarketplaceApproval(listing.source, listing.positionId, msg.sender);
        uint256 gross = offer.amountDAI;
        offer.status = OfferStatus.ACCEPTED;
        listing.status = ListingStatus.SOLD;
        totalOfferEscrow -= gross;
        bytes32 key = _positionKey(listing.source, listing.positionId);
        if (activeListingForPosition[key] == listing.listingId) {
            activeListingForPosition[key] = 0;
        }
        _settleSale(msg.sender, gross);
        _nft(listing.source).safeTransferFrom(
            msg.sender,
            offer.buyer,
            listing.positionId
        );
        _assertEscrowSolvent();
        (
            uint256 sellerAmount,
            uint256 fusereserveAmount,
            uint256 fusereactorAmount
        ) = _saleAmounts(gross);
        emit OfferAccepted(
            offerId,
            listing.listingId,
            offer.buyer,
            gross
        );
        emit ListingSold(
            listing.listingId,
            listing.positionId,
            listing.source,
            msg.sender,
            offer.buyer,
            gross,
            sellerAmount,
            fusereserveAmount,
            fusereactorAmount
        );
    }
    function withdrawInvalidatedOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        if (offer.status != OfferStatus.ACTIVE) revert OfferNotActive();
        if (offer.buyer != msg.sender) revert NotOfferBuyer();
        if (_offerStillExecutable(offer)) revert OfferStillExecutable();
        uint256 refund = offer.amountDAI;
        offer.status = OfferStatus.CANCELLED;
        totalOfferEscrow -= refund;
        DAI.safeTransfer(msg.sender, refund);
        _assertEscrowSolvent();
        emit InvalidatedOfferWithdrawn(offerId, msg.sender, refund);
    }
    // =============================================================
    // REWARD-SINK PREPARATION
    // =============================================================
    /// @notice Permissionless helper for keeping FUSEReactor eligibility current.
    /// @dev FUSEReactor itself caps a call at its protocol maximum.
    function syncFUSEReactor(uint256 maxSteps) external nonReentrant {
        FUSEReactor.syncEligibility(maxSteps);
    }
    /// @notice Permissionless helper for keeping FUSEReserve eligibility current.
    function syncFUSEReserve(uint256 maxSteps)
        external
        nonReentrant
        returns (uint256 processed, bool synced, uint256 cursor)
    {
        return FUSEReserve.syncEligibleCP(maxSteps);
    }
    /// @notice Flush accrued DAI rewards to FUSEReserve when its reward sink is ready.
    function flushFUSEReserveDAI() external nonReentrant {
        uint256 amount = pendingFUSEReserveDAI;
        if (amount == 0) return;
        pendingFUSEReserveDAI = 0;
        _flushReward(DAI, IFUSERewardSink(address(FUSEReserve)), amount);
    }
    /// @notice Flush accrued DAI rewards to FUSEReactor when its reward sink is ready.
    function flushFUSEReactorDAI() external nonReentrant {
        uint256 amount = pendingFUSEReactorDAI;
        if (amount == 0) return;
        pendingFUSEReactorDAI = 0;
        _flushReward(DAI, IFUSERewardSink(address(FUSEReactor)), amount);
    }
    /// @notice Flush accrued CV rewards to FUSEReserve when its reward sink is ready.
    function flushFUSEReserveCV() external nonReentrant {
        uint256 amount = pendingFUSEReserveCV;
        if (amount == 0) return;
        pendingFUSEReserveCV = 0;
        _flushReward(CV, IFUSERewardSink(address(FUSEReserve)), amount);
    }
    /// @notice Flush accrued CV rewards to FUSEReactor when its reward sink is ready.
    function flushFUSEReactorCV() external nonReentrant {
        uint256 amount = pendingFUSEReactorCV;
        if (amount == 0) return;
        pendingFUSEReactorCV = 0;
        _flushReward(CV, IFUSERewardSink(address(FUSEReactor)), amount);
    }
    // =============================================================
    // VIEWS
    // =============================================================
    function effectiveListingStatus(
        uint256 listingId
    ) external view returns (ListingStatus) {
        Listing storage listing = listings[listingId];
        if (
            listing.status == ListingStatus.ACTIVE &&
            block.timestamp > listing.expiresAt
        ) {
            return ListingStatus.EXPIRED;
        }
        return listing.status;
    }
    function offerWithdrawable(uint256 offerId) external view returns (bool) {
        Offer storage offer = offers[offerId];
        return
            offer.status == OfferStatus.ACTIVE &&
            !_offerStillExecutable(offer);
    }
    function escrowSolvent() external view returns (bool) {
        uint256 required =
            totalOfferEscrow +
            pendingFUSEReserveDAI +
            pendingFUSEReactorDAI;
        return DAI.balanceOf(address(this)) >= required;
    }
    /// @notice True when Reactor must be synchronized before a reward injection
    /// can safely settle.
    function reactorSyncRequired() external view returns (bool) {
        return FUSEReactor.eligibilitySyncRequired();
    }
    function saleAmounts(
        uint256 grossDAI
    )
        external
        pure
        returns (
            uint256 sellerAmount,
            uint256 fusereserveAmount,
            uint256 fusereactorAmount
        )
    {
        return _saleAmounts(grossDAI);
    }
    function marketplaceApproved(
        PositionSource source,
        uint256 positionId,
        address owner
    ) external view returns (bool) {
        return _isMarketplaceApproved(source, positionId, owner);
    }
    // =============================================================
    // INTERNAL VALIDATION
    // =============================================================
    function _requireLiveListing(Listing storage listing) internal view {
        if (listing.status != ListingStatus.ACTIVE) revert ListingNotActive();
        if (block.timestamp > listing.expiresAt) revert ListingExpired();
    }
    function _requireExecutableListing(
        Listing storage listing,
        address buyer
    ) internal view {
        _requireLiveListing(listing);
        if (buyer == listing.seller) revert SelfPurchaseForbidden();
        _validateTradablePosition(
            listing.source,
            listing.positionId,
            listing.seller
        );
        _requireMarketplaceApproval(
            listing.source,
            listing.positionId,
            listing.seller
        );
    }
    function _validateTradablePosition(
        PositionSource source,
        uint256 positionId,
        address expectedOwner
    ) internal view {
        address owner = _safeOwnerOf(source, positionId);
        if (owner != expectedOwner) revert NotPositionOwner();
        if (source == PositionSource.FUSEReserve) {
            (
                bool reserveActive,
                bool reserveMatured,
                bool reserveTransferable,
                ,
            ) = FUSEReserve.reserveStatus(positionId);
            if (!reserveActive) revert PositionNotActive();
            if (!reserveMatured) revert PositionNotMature();
            if (!reserveTransferable) revert PositionNotTransferable();
            return;
        }
        (
            bool active,
            ,
            ,
            bool matured,
            bool transferable,
            ,
            ,
            ,
        ) = FUSEReactor.positionStatus(positionId);
        if (!active) revert PositionNotActive();
        if (!matured) revert PositionNotMature();
        if (!transferable) revert PositionNotTransferable();
    }
    function _requireMarketplaceApproval(
        PositionSource source,
        uint256 positionId,
        address owner
    ) internal view {
        if (!_isMarketplaceApproved(source, positionId, owner)) {
            revert MarketplaceNotApproved();
        }
    }
    function _isMarketplaceApproved(
        PositionSource source,
        uint256 positionId,
        address owner
    ) internal view returns (bool) {
        IERC721 nft = _nft(source);
        try nft.getApproved(positionId) returns (address approved) {
            if (approved == address(this)) return true;
        } catch {
            return false;
        }
        try nft.isApprovedForAll(owner, address(this)) returns (bool approvedAll) {
            return approvedAll;
        } catch {
            return false;
        }
    }
    function _safeOwnerOf(
        PositionSource source,
        uint256 positionId
    ) internal view returns (address owner) {
        try _nft(source).ownerOf(positionId) returns (address currentOwner) {
            return currentOwner;
        } catch {
            return address(0);
        }
    }
    function _requireSameListingInstance(
        Listing storage listing,
        Offer storage offer
    ) internal view {
        if (
            listing.listingId != offer.listingId ||
            listing.source != offer.source ||
            listing.positionId != offer.positionId ||
            listing.seller != offer.expectedSeller ||
            listing.nonce != offer.listingNonce
        ) {
            revert ListingInstanceMismatch();
        }
    }
    function _offerStillExecutable(
        Offer storage offer
    ) internal view returns (bool) {
        Listing storage listing = listings[offer.listingId];
        if (listing.status != ListingStatus.ACTIVE) return false;
        if (block.timestamp > listing.expiresAt) return false;
        if (
            listing.listingId != offer.listingId ||
            listing.source != offer.source ||
            listing.positionId != offer.positionId ||
            listing.seller != offer.expectedSeller ||
            listing.nonce != offer.listingNonce
        ) {
            return false;
        }
        return _positionStillTradable(
            listing.source,
            listing.positionId,
            listing.seller
        );
    }
    function _positionStillTradable(
        PositionSource source,
        uint256 positionId,
        address expectedOwner
    ) internal view returns (bool) {
        if (_safeOwnerOf(source, positionId) != expectedOwner) {
            return false;
        }
        if (source == PositionSource.FUSEReserve) {
            try FUSEReserve.reserveStatus(positionId) returns (
                bool active,
                bool matured,
                bool transferable,
                bool,
                uint256
            ) {
                return active && matured && transferable;
            } catch {
                return false;
            }
        }
        try FUSEReactor.positionStatus(positionId) returns (
            bool active,
            bool,
            bool,
            bool matured,
            bool transferable,
            uint256,
            uint256,
            uint256,
            uint256
        ) {
            return active && matured && transferable;
        } catch {
            return false;
        }
    }
    // =============================================================
    // INTERNAL SETTLEMENT
    // =============================================================
    function _settleSale(address seller, uint256 grossDAI) internal {
        (
            uint256 sellerAmount,
            uint256 fusereserveAmount,
            uint256 fusereactorAmount
        ) = _saleAmounts(grossDAI);
        if (sellerAmount != 0) {
            DAI.safeTransfer(seller, sellerAmount);
        }
        if (fusereserveAmount != 0) {
            _accrueReward(DAI, IFUSERewardSink(address(FUSEReserve)), fusereserveAmount);
        }
        if (fusereactorAmount != 0) {
            _accrueReward(DAI, IFUSERewardSink(address(FUSEReactor)), fusereactorAmount);
        }
    }
    function _collectAndAccrueCV(
        address payer,
        IFUSERewardSink sink
    ) internal {
        _pullExact(CV, payer, ACTIVITY_FEE_CV);
        _accrueReward(CV, sink, ACTIVITY_FEE_CV);
    }
    function _accrueReward(
        IERC20 token,
        IFUSERewardSink sink,
        uint256 amount
    ) internal {
        address sinkAddress = address(sink);
        address tokenAddress = address(token);
        if (sinkAddress == address(FUSEReserve)) {
            if (tokenAddress == DAI_ADDRESS) pendingFUSEReserveDAI += amount;
            else if (tokenAddress == CV_ADDRESS) pendingFUSEReserveCV += amount;
            else revert InvalidContract();
        } else if (sinkAddress == address(FUSEReactor)) {
            if (tokenAddress == DAI_ADDRESS) pendingFUSEReactorDAI += amount;
            else if (tokenAddress == CV_ADDRESS) pendingFUSEReactorCV += amount;
            else revert InvalidContract();
        } else {
            revert InvalidContract();
        }
        emit RewardAccrued(sinkAddress, tokenAddress, amount);
    }
    function _flushReward(
        IERC20 token,
        IFUSERewardSink sink,
        uint256 amount
    ) internal {
        token.forceApprove(address(sink), amount);
        sink.injectReward(address(token), amount);
        token.forceApprove(address(sink), 0);
        emit RewardFlushed(address(sink), address(token), amount);
    }
    function _pullExact(
        IERC20 token,
        address from,
        uint256 amount
    ) internal {
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - beforeBalance;
        if (received != amount) revert ExactTransferRequired();
    }
    function _saleAmounts(
        uint256 grossDAI
    )
        internal
        pure
        returns (
            uint256 sellerAmount,
            uint256 fusereserveAmount,
            uint256 fusereactorAmount
        )
    {
        fusereserveAmount = (grossDAI * FUSERESERVE_BPS) / BPS;
        fusereactorAmount = (grossDAI * FUSEREACTOR_BPS) / BPS;
        sellerAmount =
            grossDAI -
            fusereserveAmount -
            fusereactorAmount;
    }
    function _assertEscrowSolvent() internal view {
        uint256 balance = DAI.balanceOf(address(this));
        uint256 required =
            totalOfferEscrow +
            pendingFUSEReserveDAI +
            pendingFUSEReactorDAI;
        if (balance < required) {
            revert EscrowInsolvent(balance, required);
        }
    }
    function _nft(PositionSource source) internal view returns (IERC721) {
        if (source == PositionSource.FUSEReserve) {
            return IERC721(address(FUSEReserve));
        }
        return IERC721(address(FUSEReactor));
    }
    function _positionKey(
        PositionSource source,
        uint256 positionId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(source, positionId));
    }
    function _validDuration(uint256 duration) internal pure returns (bool) {
        return
            duration == DURATION_24_HOURS ||
            duration == DURATION_7_DAYS ||
            duration == DURATION_30_DAYS;
    }
}
