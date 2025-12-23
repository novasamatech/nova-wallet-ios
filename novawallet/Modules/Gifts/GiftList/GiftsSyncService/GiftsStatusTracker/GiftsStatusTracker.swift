import Foundation
import Operation_iOS

protocol GiftsStatusTrackerProtocol: AnyObject {
    var delegate: GiftsStatusTrackerDelegate? { get set }

    func startTracking(for gift: GiftModel)

    func stopTracking(for giftAccountId: AccountId)

    func stopTracking()
}

final class GiftsStatusTracker {
    weak var delegate: GiftsStatusTrackerDelegate?

    let chainRegistry: ChainRegistryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let walletSubscriptionFactory: WalletRemoteSubscriptionFactoryProtocol
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    private let remoteBalancesSubscriptions = InMemoryCache<AccountId, WalletRemoteSubscriptionProtocol>()
    private let blockNumberProviders = InMemoryCache<AccountId, AnyDataProvider<DecodedBlockNumber>>()
    private let syncingAccountIdsCache = InMemoryCache<AccountId, Bool>()
    private let nilBalanceStartBlocks = InMemoryCache<AccountId, BlockNumber>()
    private let giftTimelineChainMapping = InMemoryCache<AccountId, ChainModel.Id>()
    private let existingBalances = InMemoryCache<AccountId, AssetBalance>()

    private let blocksToWait: BlockNumber = 10

    init(
        chainRegistry: ChainRegistryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        walletSubscriptionFactory: WalletRemoteSubscriptionFactoryProtocol,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.walletSubscriptionFactory = walletSubscriptionFactory
        self.workingQueue = workingQueue
        self.logger = logger
    }

    deinit {
        stopTracking()
    }
}

// MARK: - Private

private extension GiftsStatusTracker {
    func addRemoteBalanceSubscription(
        for gift: GiftModel,
        chainAsset: ChainAsset
    ) {
        let subscription = walletSubscriptionFactory.createSubscription()

        remoteBalancesSubscriptions.store(
            value: subscription,
            for: gift.giftAccountId
        )

        subscription.subscribeBalance(
            for: gift.giftAccountId,
            chainAsset: chainAsset,
            callbackQueue: workingQueue,
            callbackClosure: { [weak self] result in
                switch result {
                case let .success(update):
                    self?.handleBalanceUpdate(
                        for: gift,
                        balance: update.balance,
                        chain: chainAsset.chain
                    )
                case let .failure(error):
                    self?.logger.error("Failed remote balance subscription: \(error)")
                }
            }
        )
    }

    func handleBalanceUpdate(
        for gift: GiftModel,
        balance: AssetBalance?,
        chain: ChainModel
    ) {
        let giftAccountId = gift.giftAccountId

        var status: GiftModel.Status?

        if let balance, balance.transferable > (gift.amount / 2) {
            existingBalances.store(value: balance, for: giftAccountId)
            status = .pending
        } else if balance != nil || existingBalances.fetchValue(for: giftAccountId) != nil {
            // don't wait for previously tracked gifts since we know for sure that they existed
            status = .claimed
        }

        guard let status else {
            startBlockCountingIfNeeded(
                for: giftAccountId,
                chainId: timelineChainId(for: chain)
            )

            return
        }

        cancelBlockCounting(for: giftAccountId)
        removeSyncingAccountId(giftAccountId)

        delegate?.giftsTracker(
            self,
            didReceive: status,
            for: giftAccountId
        )
    }

    // MARK: - Block counting

    func startBlockCountingIfNeeded(
        for giftAccountId: AccountId,
        chainId: ChainModel.Id
    ) {
        guard
            nilBalanceStartBlocks.fetchValue(for: giftAccountId) == nil,
            blockNumberProviders.fetchValue(for: giftAccountId) == nil,
            let provider = subscribeToBlockNumber(for: chainId)
        else { return }

        blockNumberProviders.store(
            value: provider,
            for: giftAccountId
        )
    }

    func cancelBlockCounting(for giftAccountId: AccountId) {
        nilBalanceStartBlocks.removeValue(for: giftAccountId)
        blockNumberProviders.removeValue(for: giftAccountId)
    }

    func checkBlockProgress(
        for giftAccountId: AccountId,
        currentBlock: BlockNumber
    ) {
        guard let startBlock = nilBalanceStartBlocks.fetchValue(for: giftAccountId) else {
            nilBalanceStartBlocks.store(
                value: currentBlock,
                for: giftAccountId
            )
            return
        }

        let blocksPassed = currentBlock > startBlock ? currentBlock - startBlock : 0

        guard blocksPassed >= blocksToWait else { return }

        cancelBlockCounting(for: giftAccountId)
        removeSyncingAccountId(giftAccountId)
        existingBalances.removeValue(for: giftAccountId)

        delegate?.giftsTracker(
            self,
            didReceive: .claimed,
            for: giftAccountId
        )
    }

    // MARK: - Syncing Account Ids Management

    func addSyncingAccountId(_ accountId: AccountId) {
        let wasAbsent = syncingAccountIdsCache.fetchValue(for: accountId) == nil
        syncingAccountIdsCache.store(value: true, for: accountId)

        guard wasAbsent else { return }

        notifyDelegateAboutSyncingAccountIds()
    }

    func removeSyncingAccountId(_ accountId: AccountId) {
        let wasPresent = syncingAccountIdsCache.fetchValue(for: accountId) != nil
        syncingAccountIdsCache.removeValue(for: accountId)

        guard wasPresent else { return }

        notifyDelegateAboutSyncingAccountIds()
    }

    func clearSyncingAccountIds() {
        syncingAccountIdsCache.removeAllValues()
        notifyDelegateAboutSyncingAccountIds()
    }

    func notifyDelegateAboutSyncingAccountIds() {
        delegate?.giftsTracker(
            self,
            didUpdateTrackingAccountIds: Set(syncingAccountIdsCache.fetchAllKeys())
        )
    }

    func timelineChainId(for chain: ChainModel) -> ChainModel.Id {
        chain.timelineChain ?? chain.chainId
    }
}

// MARK: - GiftsStatusTrackerProtocol

extension GiftsStatusTracker: GiftsStatusTrackerProtocol {
    func startTracking(for gift: GiftModel) {
        guard
            let chain = chainRegistry.getChain(for: gift.chainAssetId.chainId),
            let chainAsset = chain.chainAsset(for: gift.chainAssetId.assetId)
        else { return }

        let giftAccountId = gift.giftAccountId

        addSyncingAccountId(giftAccountId)

        giftTimelineChainMapping.store(
            value: timelineChainId(for: chain),
            for: giftAccountId
        )

        addRemoteBalanceSubscription(
            for: gift,
            chainAsset: chainAsset
        )
    }

    func stopTracking(for giftAccountId: AccountId) {
        remoteBalancesSubscriptions.fetchValue(for: giftAccountId)?.unsubscribe()
        remoteBalancesSubscriptions.removeValue(for: giftAccountId)
        blockNumberProviders.removeValue(for: giftAccountId)
        nilBalanceStartBlocks.removeValue(for: giftAccountId)
        giftTimelineChainMapping.removeValue(for: giftAccountId)
        existingBalances.removeValue(for: giftAccountId)
        removeSyncingAccountId(giftAccountId)
    }

    func stopTracking() {
        remoteBalancesSubscriptions.fetchAllValues().forEach { $0.unsubscribe() }
        remoteBalancesSubscriptions.removeAllValues()
        blockNumberProviders.fetchAllValues().forEach { $0.removeObserver(self) }
        blockNumberProviders.removeAllValues()
        nilBalanceStartBlocks.removeAllValues()
        giftTimelineChainMapping.removeAllValues()
        existingBalances.removeAllValues()
        clearSyncingAccountIds()
    }
}

// MARK: - GeneralLocalStorageSubscriber

extension GiftsStatusTracker: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            workingQueue.async {
                guard let blockNumber else { return }
                
                self.giftTimelineChainMapping
                    .fetchAllPairs()
                    .forEach { giftAccountId, giftChainId in
                        guard
                            giftChainId == chainId,
                            self.blockNumberProviders.fetchValue(for: giftAccountId) != nil
                        else { return }

                        self.checkBlockProgress(for: giftAccountId, currentBlock: blockNumber)
                    }
            }
        case let .failure(error):
            logger.error("Failed block number subscription: \(error)")
        }
    }
}
