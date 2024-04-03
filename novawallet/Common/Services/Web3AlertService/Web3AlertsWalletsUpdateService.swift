import Foundation
import RobinHood
import SubstrateSdk

final class Web3AlertsWalletsUpdateService: BaseSyncService {
    let chainRegistry: ChainRegistryProtocol
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let settingsService: Web3AlertsSyncServiceProtocol
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private let walletsCancellable = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        settingsService: Web3AlertsSyncServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRegistry = chainRegistry
        self.walletsRepository = walletsRepository
        self.settingsService = settingsService
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    private func updateWallets(
        for chains: [ChainModel.Id: ChainModel],
        localWallets: [MetaAccountModel.Id: MetaAccountModel]
    ) {
        guard isSyncing else {
            logger.warning("Wallets received but sync cancelled")
            return
        }

        settingsService.updateWallets(
            dependingOn: { localWallets },
            chainsClosure: { chains },
            runningIn: workingQueue,
            completionHandler: { [weak self] optError in
                self?.complete(optError)
            }
        )
    }

    private func loadWalletsAndSync(for chains: [ChainModel.Id: ChainModel]) {
        let walletsOperations = walletsRepository.fetchAllOperation(with: .init())

        let wrapper = CompoundOperationWrapper(targetOperation: walletsOperations)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: walletsCancellable,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(wallets):
                self?.updateWallets(for: chains, localWallets: wallets.reduceToDict())
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    override func performSyncUp() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue
        ) { [weak self] changes in
            guard let self = self, self.getIsSyncing() else {
                self?.logger.warning("Chains received but sync cancelled")
                return
            }

            self.chainRegistry.chainsUnsubscribe(self)

            let chainsDict = changes.mergeToDict([:])

            self.loadWalletsAndSync(for: chainsDict)
        }
    }

    override func stopSyncUp() {
        walletsCancellable.cancel()
        chainRegistry.chainsUnsubscribe(self)
    }
}
