import Foundation
import SubstrateSdk
import Operation_iOS

protocol MultisigPendingOperationsSyncServiceProtocol: ApplicationServiceProtocol {}

class MultisigPendingOperationsSyncService {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let callDataSyncService: MultisigCallDataSyncServiceProtocol
    private let chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private var pendingOperationsChainSyncServices: [ChainModel.Id: PendingMultisigChainSyncServiceProtocol] = [:]

    private var selectedMetaAccountProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var knownCallData: [Multisig.PendingOperation.Key: JSON] = [:]

    private var selectedMetaAccount: MetaAccountModel? {
        didSet {
            if oldValue == nil, selectedMetaAccount != oldValue {
                setupCallDataSync()
            }

            if let selectedMetaAccount,
               selectedMetaAccount != oldValue {
                if selectedMetaAccount.multisigAccount != nil {
                    createChainSyncServices(for: selectedMetaAccount)
                } else {
                    pendingOperationsChainSyncServices.forEach { $0.value.stopSyncUp() }
                    pendingOperationsChainSyncServices = [:]
                }
            }
        }
    }

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        callDataSyncService: MultisigCallDataSyncServiceProtocol,
        chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.sync.service"),
        logger: LoggerProtocol? = nil
    ) {
        self.chainRepository = chainRepository
        self.callDataSyncService = callDataSyncService
        self.chainSyncServiceFactory = chainSyncServiceFactory
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigPendingOperationsSyncService {
    func performSetup() {
        mutex.lock()
        defer { mutex.unlock() }

        selectedMetaAccountProvider = subscribeSelectedWalletProvider()
    }

    func setupCallDataSync() {
        let chainsFetchOperation = chainRepository.fetchAllOperation(with: .init())

        execute(
            operation: chainsFetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(chains):
                let filteredChains = chains.filter { $0.hasMultisig }

                callDataSyncService.addObserver(
                    self,
                    sendOnSubscription: true
                )
                callDataSyncService.setup(with: filteredChains)
            case let .failure(error):
                logger?.error("Failed to fetch chains: \(error)")
            }
        }
    }

    func createChainSyncServices(for selectedMetaAccount: MetaAccountModel) {
        pendingOperationsChainSyncServices.forEach { $0.value.stopSyncUp() }

        let chainsFetchOperation = chainRepository.fetchAllOperation(with: .init())

        execute(
            operation: chainsFetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(chains):
                let filteredChains = chains.filter { $0.hasMultisig }
                mutex.lock()
                pendingOperationsChainSyncServices = filteredChains.reduce(into: [:]) { _, chain in
                    let service = self.chainSyncServiceFactory.createMultisigChainSyncService(
                        for: chain,
                        selectedMetaAccount: selectedMetaAccount,
                        knownCallData: self.knownCallData,
                        operationQueue: self.operationQueue
                    )
                    self.pendingOperationsChainSyncServices[chain.chainId] = service
                }
                pendingOperationsChainSyncServices.forEach { $0.value.setup() }
                mutex.unlock()
            case let .failure(error):
                logger?.error("Failed to fetch chains: \(error)")
            }
        }
    }
}

// MARK: - MultisigPendingOperationsSyncServiceProtocol

extension MultisigPendingOperationsSyncService: MultisigPendingOperationsSyncServiceProtocol {
    func setup() {
        performSetup()
    }

    func throttle() {
        mutex.lock()
        defer { mutex.unlock() }

        pendingOperationsChainSyncServices.forEach { $0.value.stopSyncUp() }
        callDataSyncService.stopSyncUp()
        selectedMetaAccountProvider = nil
    }
}

// MARK: - WalletListLocalStorageSubscriber

extension MultisigPendingOperationsSyncService: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleSelectedWallet(result: Result<ManagedMetaAccountModel?, any Error>) {
        switch result {
        case let .success(selectedMetaAccount):
            mutex.lock()
            self.selectedMetaAccount = selectedMetaAccount?.info
            mutex.unlock()
        case let .failure(error):
            logger?.error("Failed to fetch selected wallet: \(error.localizedDescription)")
        }
    }
}

// MARK: - MultisigCallDataObserver

extension MultisigPendingOperationsSyncService: MultisigCallDataObserver {
    func didReceive(newCallData: [Multisig.PendingOperation.Key: JSON]) {
        mutex.lock()
        defer { mutex.unlock() }
        
        knownCallData.merge(newCallData, uniquingKeysWith: { $1 })
        
        pendingOperationsChainSyncServices.forEach {
            $0.value.updatePendingOperationsCallData(using: newCallData)
        }
    }
}

// MARK: - Errors

enum MultisigPendingOperationsSyncError: Error {
    case noChainMatchingMultisigAccount
    case multisigAccountUnavailable
    case localPendingOperationUnavailable
}
