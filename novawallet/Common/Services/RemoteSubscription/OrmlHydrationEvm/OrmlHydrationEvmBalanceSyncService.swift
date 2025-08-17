import Foundation
import Operation_iOS

final class OrmlHydrationEvmBalanceSyncService {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let balanceRepository: AnyDataProviderRepository<AssetBalance>
    let transactionHandlerFactory: TransactionSubscriptionFactoryProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let mutex = NSLock()

    private var trigger: ChainPollingStateStore?
    private var subscriptionServices: [ApplicationServiceProtocol]?
    private var transactionHandler: TransactionSubscribing?

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        balanceRepository: AnyDataProviderRepository<AssetBalance>,
        transactionHandlerFactory: TransactionSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.balanceRepository = balanceRepository
        self.transactionHandlerFactory = transactionHandlerFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }
}

private extension OrmlHydrationEvmBalanceSyncService {
    func updateBalance(_ balance: AssetBalance) {
        logger.debug("Saving changed balance \(balance)")

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

        operationQueue.addOperation(saveOperation)
    }

    func handleTransactions(on blockHashData: BlockHashData) {
        transactionHandler?.process(blockHash: blockHashData)
    }

    func setupSubscriptions(for chainAssetIds: [ChainAssetId], trigger: ChainPollingStateStore) {
        subscriptionServices = chainAssetIds.map { chainAssetId in
            OrmlHydrationEvmSubscriptionService(
                chainAssetId: chainAssetId,
                accountId: accountId,
                trigger: trigger,
                chainRegistry: chainRegistry,
                operationQueue: operationQueue,
                workingQueue: workingQueue,
                logger: logger,
                callbackQueue: workingQueue
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
                chainId: chainId,
                chainRegistry: chainRegistry,
                operationQueue: operationQueue,
                workingQueue: workingQueue,
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
