import Foundation
import Operation_iOS

protocol GiftsSyncServiceProtocol {
    func start()
}

final class GiftsSyncService {
    let chainRegistry: ChainRegistryProtocol
    let giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol
    let assetStorageOperationFactory: AssetStorageInfoOperationFactoryProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    var giftsLocalSubscription: StreamableProvider<GiftModel>?
    var remoteBalancesSubscriptions: [AccountId: WalletRemoteSubscriptionProtocol] = [:]

    var balanceExistences: [ChainAssetId: AssetBalanceExistence] = [:]

    let mutex = NSLock()

    init(
        chainRegistry: ChainRegistryProtocol,
        giftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol,
        assetStorageOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        giftRepository: AnyDataProviderRepository<GiftModel>,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.giftsLocalSubscriptionFactory = giftsLocalSubscriptionFactory
        self.assetStorageOperationFactory = assetStorageOperationFactory
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

        let balanceExistenceWrapper = createBalanceExistenceWrapper(for: chainAsset)

        execute(
            wrapper: balanceExistenceWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(balanceExistence):
                mutex.lock()
                defer { mutex.unlock() }

                balanceExistences[chainAsset.chainAssetId] = balanceExistence

                addRemoteBalanceSubscription(
                    for: gift,
                    balanceExistence: balanceExistence,
                    chainAsset: chainAsset
                )
            case let .failure(error):
                logger.error("Failed on fetch asset storage info: \(error)")
            }
        }
    }

    func createBalanceExistenceWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)

            return if let balanceExistence = balanceExistences[chainAsset.chainAssetId] {
                .createWithResult(balanceExistence)
            } else {
                assetStorageOperationFactory.createAssetBalanceExistenceOperation(
                    chainId: chainAsset.chain.chainId,
                    asset: chainAsset.asset,
                    runtimeProvider: runtimeProvider,
                    operationQueue: operationQueue
                )
            }
        } catch {
            return .createWithError(error)
        }
    }

    func addRemoteBalanceSubscription(
        for gift: GiftModel,
        balanceExistence: AssetBalanceExistence,
        chainAsset: ChainAsset
    ) {
        let subscription = WalletRemoteSubscription(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )

        remoteBalancesSubscriptions[gift.giftAccountId] = subscription

        subscription.subscribeBalance(
            for: gift.giftAccountId,
            chainAsset: chainAsset,
            callbackQueue: workingQueue,
            callbackClosure: { [weak self] result in
                switch result {
                case let .success(update):
                    self?.updateStatus(
                        for: gift,
                        chainAssetId: chainAsset.chainAssetId,
                        balance: update.balance,
                        balanceExistence: balanceExistence
                    )
                case let .failure(error):
                    self?.logger.error("Failed remote balance subscription: \(error)")
                }
            }
        )
    }

    func updateStatus(
        for gift: GiftModel,
        chainAssetId _: ChainAssetId,
        balance: AssetBalance?,
        balanceExistence: AssetBalanceExistence
    ) {
        let status: GiftModel.Status = if let balance, balance.transferable > balanceExistence.minBalance {
            .pending
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
