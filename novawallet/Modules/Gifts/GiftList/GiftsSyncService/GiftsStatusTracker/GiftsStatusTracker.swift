import Foundation
import Operation_iOS
import SubstrateSdk

protocol GiftsStatusTrackerProtocol: AnyObject {
    var delegate: GiftsStatusTrackerDelegate? { get set }

    func startTracking(for gift: GiftModel)

    func stopTracking(for giftAccountId: AccountId)

    func stopTracking()
}

final class GiftsStatusTracker {
    weak var delegate: GiftsStatusTrackerDelegate?

    let chainRegistry: ChainRegistryProtocol
    let walletSubscriptionFactory: WalletRemoteSubscriptionFactoryProtocol
    let blockNumberSubscriptionFactory: BlockNumberCallbackSubscriptionFactoryProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    private let remoteBalancesSubscriptions = InMemoryCache<AccountId, WalletRemoteSubscriptionProtocol>()
    private let blockNumberSubscriptions = InMemoryCache<AccountId, BlockNumberRemoteSubscriptionProtocol>()
    private let syncingAccountIdsCache = InMemoryCache<AccountId, Bool>()
    private let nilBalanceStartBlocks = InMemoryCache<AccountId, BlockNumber>()
    private let giftChainMapping = InMemoryCache<AccountId, ChainModel.Id>()
    private let existingBalances = InMemoryCache<AccountId, AssetBalance>()

    private let blocksToWait: BlockNumber = 10

    init(
        chainRegistry: ChainRegistryProtocol,
        walletSubscriptionFactory: WalletRemoteSubscriptionFactoryProtocol,
        blockNumberSubscriptionFactory: BlockNumberCallbackSubscriptionFactoryProtocol,
        workingQueue: DispatchQueue,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.walletSubscriptionFactory = walletSubscriptionFactory
        self.blockNumberSubscriptionFactory = blockNumberSubscriptionFactory
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
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
                        chainId: chainAsset.chain.chainId
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
        chainId: ChainModel.Id
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
                chainId: chainId
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
            blockNumberSubscriptions.fetchValue(for: giftAccountId) == nil
        else { return }

        do {
            let subscription = try blockNumberSubscriptionFactory.createSubscription(
                for: chainId
            )

            try subscription.start { [weak self, chainId, giftAccountId] result in
                guard let self else { return }

                switch result {
                case let .success(blockNumber):
                    guard let blockNumber else { return }

                    handle(blockNumber, on: chainId)
                case let .failure(error):
                    logger.error("Failed block number subscription: \(error)")

                    cancelBlockCounting(for: giftAccountId)
                }
            }

            blockNumberSubscriptions.store(
                value: subscription,
                for: giftAccountId
            )
        } catch {
            logger.error("Failed block number subscription: \(error)")
        }
    }

    func handle(
        _ blockNumber: BlockNumber,
        on chainId: ChainModel.Id
    ) {
        giftChainMapping.fetchAllPairs().forEach { giftAccountId, giftChainId in
            guard
                giftChainId == chainId,
                blockNumberSubscriptions.fetchValue(for: giftAccountId) != nil
            else { return }

            self.checkBlockProgress(for: giftAccountId, currentBlock: blockNumber)
        }
    }

    func cancelBlockCounting(for giftAccountId: AccountId) {
        nilBalanceStartBlocks.removeValue(for: giftAccountId)
        blockNumberSubscriptions.removeValue(for: giftAccountId)
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

        giftChainMapping.store(
            value: chain.chainId,
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
        blockNumberSubscriptions.removeValue(for: giftAccountId)
        nilBalanceStartBlocks.removeValue(for: giftAccountId)
        giftChainMapping.removeValue(for: giftAccountId)
        existingBalances.removeValue(for: giftAccountId)
        removeSyncingAccountId(giftAccountId)
    }

    func stopTracking() {
        remoteBalancesSubscriptions.fetchAllValues().forEach { $0.unsubscribe() }
        remoteBalancesSubscriptions.removeAllValues()
        blockNumberSubscriptions.fetchAllValues().forEach { $0.unsubscribe() }
        blockNumberSubscriptions.removeAllValues()
        nilBalanceStartBlocks.removeAllValues()
        giftChainMapping.removeAllValues()
        existingBalances.removeAllValues()
        clearSyncingAccountIds()
    }
}
