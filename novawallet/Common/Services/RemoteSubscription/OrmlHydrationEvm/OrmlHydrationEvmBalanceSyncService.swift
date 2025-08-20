import Foundation
import Operation_iOS

final class OrmlHydrationEvmBalanceSyncService {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let balanceRepository: AnyDataProviderRepository<AssetBalance>
    let transactionHandlerFactory: TransactionSubscriptionFactoryProtocol
    let syncQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let mutex = NSLock()

    private var trigger: ChainPollingStateStore?
    private var subscriptionServices: [ApplicationServiceProtocol]?
    private var transactionHandler: TransactionSubscribing?

    private var saveCallStore: CancellableCallStore?

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        balanceRepository: AnyDataProviderRepository<AssetBalance>,
        transactionHandlerFactory: TransactionSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.balanceRepository = balanceRepository
        self.transactionHandlerFactory = transactionHandlerFactory
        self.operationQueue = operationQueue
        syncQueue = DispatchQueue(label: "io.novawallet.ormlhydraevm.sync.\(UUID().uuidString)")
        self.logger = logger
    }
}

private extension OrmlHydrationEvmBalanceSyncService {
    func updateBalance(_ balance: AssetBalance) {
        logger.debug("Saving changed balance \(balance)")

        let newCallStore = CancellableCallStore()

        let saveOperation = balanceRepository.saveOperation({
            guard !balance.isZero else {
                return []
            }

            return [balance]
        }, {
            if balance.isZero {
                return [balance.identifier]
            } else {
                return []
            }
        })

        // make sure we completely save previous balance before trying new one
        let processingWrapper = CompoundOperationWrapper(targetOperation: saveOperation)

        saveCallStore?.addDependency(to: processingWrapper)
        saveCallStore = newCallStore

        executeCancellable(
            wrapper: processingWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: newCallStore,
            runningCallbackIn: nil,
            callbackClosure: { _ in }
        )
    }

    func handleTransactions(on blockHashData: BlockHashData) {
        transactionHandler?.process(blockHash: blockHashData)
    }

    func setupSubscriptions(for chainAssetIds: [ChainAssetId], trigger: ChainPollingStateStore) {
        subscriptionServices = chainAssetIds.map { chainAssetId in
            // With sync queue as parameter we are make sure that events of balance change will be passed
            // and handled in the right order
            OrmlHydrationEvmSubscriptionService(
                chainAssetId: chainAssetId,
                accountId: accountId,
                trigger: trigger,
                chainRegistry: chainRegistry,
                operationQueue: operationQueue,
                workingQueue: syncQueue,
                logger: logger,
                callbackQueue: syncQueue
            ) { [weak self] newBalance, blockHash in
                guard let self else {
                    return
                }

                mutex.lock()

                defer {
                    mutex.unlock()
                }

                updateBalance(newBalance)
                handleTransactions(on: blockHash)
            }
        }

        subscriptionServices?.forEach { $0.setup() }
    }
}

extension OrmlHydrationEvmBalanceSyncService: ApplicationServiceProtocol {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard trigger == nil else {
            return
        }

        do {
            let chain = try chainRegistry.getChainOrError(for: chainId)

            let chainAssetIds: [ChainAssetId] = chain.assets.compactMap { asset in
                guard AssetType(rawType: asset.type) == .ormlHydrationEvm else {
                    return nil
                }

                return ChainAssetId(chainId: chainId, assetId: asset.assetId)
            }

            guard !chainAssetIds.isEmpty else {
                return
            }

            let trigger = ChainPollingStateStore(
                runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                    chainId: chainId,
                    chainRegistry: chainRegistry
                ),
                operationQueue: operationQueue,
                workQueue: syncQueue,
                logger: logger
            )

            trigger.setup()
            self.trigger = trigger

            transactionHandler = try transactionHandlerFactory.createTransactionSubscription(
                for: accountId,
                chain: chain
            )

            setupSubscriptions(for: chainAssetIds, trigger: trigger)

        } catch {
            logger.error("Uexpected error: \(error)")
        }
    }

    func throttle() {
        trigger?.throttle()

        subscriptionServices?.forEach { $0.throttle() }

        trigger = nil
        subscriptionServices = nil
        transactionHandler = nil
    }
}
