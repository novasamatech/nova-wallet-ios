import Foundation
import Operation_iOS

protocol GiftsSyncServiceProtocol {
    func start()
}

final class GiftsSyncService {
    let chainRegistry: ChainRegistryProtocol
    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    var giftsLocalSubscription: StreamableProvider<GiftModel>?
    var remoteBalancesSubscriptions: [AccountId: WalletRemoteSubscriptionProtocol] = [:]

    var gifts: [GiftModel.Id: GiftModel] = [:]

    let mutex = NSLock()

    init(
        chainRegistry: ChainRegistryProtocol,
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        giftRepository: AnyDataProviderRepository<GiftModel>,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.giftRepository = giftRepository
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }

    deinit {
        clearSubscriptions()
    }
}

// MARK: - Private

private extension GiftsSyncService {
    func setup() {
        giftsLocalSubscription = subscribeAllGifts()
    }

    func clearSubscriptions() {
        remoteBalancesSubscriptions.values.forEach { $0.unsubscribe() }
        remoteBalancesSubscriptions = [:]
        giftsLocalSubscription = nil
    }

    func updateSubscriptions(for changes: [DataProviderChange<GiftModel>]) {
        changes
            .compactMap(\.item)
            .filter { $0.status == .pending }
            .forEach { subscribeBalance(for: $0) }

        changes
            .compactMap(\.item)
            .filter { $0.status == .claimed || $0.status == .reclaimed }
            .forEach { unsubscribeBalance(for: $0) }
    }

    func unsubscribeBalance(for gift: GiftModel) {
        remoteBalancesSubscriptions[gift.giftAccountId]?.unsubscribe()
        remoteBalancesSubscriptions[gift.giftAccountId] = nil
    }

    func subscribeBalance(for gift: GiftModel) {
        guard
            let chain = chainRegistry.getChain(for: gift.chainAssetId.chainId),
            let chainAsset = chain.chainAsset(for: gift.chainAssetId.assetId)
        else { return }

        addRemoteBalanceSubscription(
            for: gift.giftAccountId,
            chainAsset: chainAsset
        )
    }

    func addRemoteBalanceSubscription(
        for giftAccountId: AccountId,
        chainAsset: ChainAsset
    ) {
        let subscription = WalletRemoteSubscription(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )

        remoteBalancesSubscriptions[giftAccountId] = subscription

        subscription.subscribeBalance(
            for: giftAccountId,
            chainAsset: chainAsset,
            callbackQueue: workingQueue,
            callbackClosure: { [weak self] result in
                switch result {
                case let .success(update):
                    self?.mutex.lock()
                    defer { self?.mutex.unlock() }

                    self?.updateStatus(
                        for: giftAccountId,
                        balance: update.balance,
                        asset: chainAsset.asset
                    )
                case let .failure(error):
                    self?.logger.error("Failed remote balance subscription: \(error)")
                }
            }
        )
    }

    func updateStatus(
        for giftAccountId: AccountId,
        balance: AssetBalance?,
        asset: AssetModel
    ) {
        guard let gift = gifts[giftAccountId.toHex()] else { return }

        // TODO: - Remove after polling or any other submission monitoring implementation for EVM transactions
        /// We take some time for block finalization, otherwise we will lock user's gift 
        if asset.isAnyEvm {
            guard gift.creationDate.distance(to: Date()) > 60 else { return }
        }

        let status: GiftModel.Status = if let balance, balance.transferable > gift.amount {
            .pending
        } else if gift.senderMetaId != nil {
            .reclaimed
        } else {
            .claimed
        }

        guard gift.status != status else { return }

        let saveOperation = giftRepository.saveOperation(
            { [gift.updating(status: status)] },
            { [] }
        )

        operationQueue.addOperations([saveOperation], waitUntilFinished: false)
    }
}

// MARK: - GiftsLocalStorageSubscriber

extension GiftsSyncService: GiftsLocalStorageSubscriber, GiftsLocalSubscriptionHandler {
    func handleAllGifts(result: Result<[DataProviderChange<GiftModel>], any Error>) {
        mutex.lock()
        defer { mutex.unlock() }

        switch result {
        case let .success(changes):
            gifts = changes.mergeToDict(gifts)
            updateSubscriptions(for: changes)
        case let .failure(error):
            logger.error("Failed on gifts subscription: \(error)")
        }
    }
}

// MARK: - GiftsSyncServiceProtocol

extension GiftsSyncService: GiftsSyncServiceProtocol {
    func start() {
        setup()
    }
}
