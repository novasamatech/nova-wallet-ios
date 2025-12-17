import Foundation
import Operation_iOS

protocol GiftsSyncerDelegate: AnyObject {
    func giftsSyncer(
        _ syncer: GiftsSyncer,
        didReceive status: GiftModel.Status,
        for giftAccountId: AccountId
    )

    func giftsSyncer(
        _ syncer: GiftsSyncer,
        didUpdateSyncingAccountIds accountIds: Set<AccountId>
    )
}

protocol GiftsSyncerProtocol: AnyObject {
    var delegate: GiftsSyncerDelegate? { get set }
    
    func startSyncing(for gift: GiftModel)
    
    func stopSyncing(for giftAccountId: AccountId)
    
    func stopSyncing()
}

final class GiftsSyncer {
    weak var delegate: GiftsSyncerDelegate?

    let chainRegistry: ChainRegistryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    private let remoteBalancesSubscriptions = InMemoryCache<AccountId, WalletRemoteSubscriptionProtocol>()
    private let blockNumberProviders = InMemoryCache<AccountId, AnyDataProvider<DecodedBlockNumber>>()
    private let syncingAccountIdsCache = InMemoryCache<AccountId, Bool>()
    private let nilBalanceStartBlocks = InMemoryCache<AccountId, BlockNumber>()
    private let giftChainMapping = InMemoryCache<AccountId, ChainModel.Id>()
    private let currentBlockNumbers = InMemoryCache<ChainModel.Id, BlockNumber>()

    private let blocksToWait: BlockNumber = 10

    init(
        chainRegistry: ChainRegistryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }

    deinit {
        stopSyncing()
    }
}

// MARK: - Private

private extension GiftsSyncer {
    func addRemoteBalanceSubscription(
        for giftAccountId: AccountId,
        chainAsset: ChainAsset
    ) {
        let subscription = WalletRemoteSubscription(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )

        remoteBalancesSubscriptions.store(
            value: subscription,
            for: giftAccountId
        )

        subscription.subscribeBalance(
            for: giftAccountId,
            chainAsset: chainAsset,
            callbackQueue: workingQueue,
            callbackClosure: { [weak self] result in
                switch result {
                case let .success(update):
                    self?.handleBalanceUpdate(
                        for: giftAccountId,
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
        for giftAccountId: AccountId,
        balance: AssetBalance?,
        chainId: ChainModel.Id
    ) {
        guard let balance else {
            startBlockCountingIfNeeded(
                for: giftAccountId,
                chainId: chainId
            )

            return
        }

        let status: GiftModel.Status = if balance.transferable > 0 {
            .pending
        } else {
            .claimed
        }

        cancelBlockCounting(for: giftAccountId)
        removeSyncingAccountId(giftAccountId)

        delegate?.giftsSyncer(
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

        delegate?.giftsSyncer(
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
        delegate?.giftsSyncer(
            self,
            didUpdateSyncingAccountIds: Set(syncingAccountIdsCache.fetchAllKeys())
        )
    }
}

// MARK: - GiftsSyncerProtocol

extension GiftsSyncer: GiftsSyncerProtocol {
    func startSyncing(for gift: GiftModel) {
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
            for: giftAccountId,
            chainAsset: chainAsset
        )
    }

    func stopSyncing(for giftAccountId: AccountId) {
        remoteBalancesSubscriptions.fetchValue(for: giftAccountId)?.unsubscribe()
        remoteBalancesSubscriptions.removeValue(for: giftAccountId)
        blockNumberProviders.removeValue(for: giftAccountId)
        nilBalanceStartBlocks.removeValue(for: giftAccountId)
        giftChainMapping.removeValue(for: giftAccountId)
        removeSyncingAccountId(giftAccountId)
    }
    
    func stopSyncing() {
        remoteBalancesSubscriptions.fetchAllValues().forEach { $0.unsubscribe() }
        remoteBalancesSubscriptions.removeAllValues()
        blockNumberProviders.removeAllValues()
        nilBalanceStartBlocks.removeAllValues()
        giftChainMapping.removeAllValues()
        currentBlockNumbers.removeAllValues()
        clearSyncingAccountIds()
    }
}

// MARK: - GeneralLocalStorageSubscriber

extension GiftsSyncer: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    var generalLocalSubscriptionHandler: GeneralLocalStorageHandler { self }

    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            guard let blockNumber else { return }

            currentBlockNumbers.store(value: blockNumber, for: chainId)

            for (giftAccountId, giftChainId) in giftChainMapping.fetchAllPairs() where giftChainId == chainId {
                guard nilBalanceStartBlocks.fetchValue(for: giftAccountId) != nil else { continue }

                checkBlockProgress(for: giftAccountId, currentBlock: blockNumber)
            }
        case let .failure(error):
            logger.error("Failed block number subscription: \(error)")
        }
    }
}
