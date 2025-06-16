import Foundation
import Operation_iOS

protocol MultisigPendingOperationsSyncServiceProtocol: ApplicationServiceProtocol {}

class MultisigPendingOperationsSyncService {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private var pendingOperationsChainSyncServices: [ChainModel.Id: PendingMultisigChainSyncServiceProtocol] = [:]
    
    private var selectedMetaAccountProvider: StreamableProvider<ManagedMetaAccountModel>?
    private var metaAccountsProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var availableMetaAccounts: [MetaAccountModel] = []
    
    private var selectedMetaAccount: MetaAccountModel? {
        didSet {
            if selectedMetaAccount?.metaId != oldValue?.metaId {
                createChainSyncServices()
            }
        }
    }

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.sync.service"),
        logger: LoggerProtocol? = nil
    ) {
        self.chainRepository = chainRepository
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
        
        metaAccountsProvider = subscribeAllWalletsProvider()
        selectedMetaAccountProvider = subscribeSelectedWalletProvider()
    }
    
    func createChainSyncServices() {
        guard availableMetaAccounts.contains(where: { $0.multisigAccount != nil }) else {
            return
        }
        
        guard let selectedMetaAccount, selectedMetaAccount.multisigAccount != nil else {
            return
        }
        
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
                pendingOperationsChainSyncServices = filteredChains.reduce(into: [:]) { acc, chain in
                    let service = self.chainSyncServiceFactory.createMultisigChainSyncService(
                        for: chain,
                        selectedMetaAccount: selectedMetaAccount,
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
        selectedMetaAccountProvider = nil
        metaAccountsProvider = nil
    }
}

// MARK: - WalletListLocalStorageSubscriber

extension MultisigPendingOperationsSyncService: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            let mappedChanges: [DataProviderChange<MetaAccountModel>] = changes
                .compactMap { change in
                    guard change.isDeletion || change.item?.info.delegationId?.delegationType == .multisig else {
                        return nil
                    }

                    return switch change {
                    case let .insert(newItem): .insert(newItem: newItem.info)
                    case let .update(newItem): .update(newItem: newItem.info)
                    case let .delete(deletedIdentifier): .delete(deletedIdentifier: deletedIdentifier)
                    }
                }

            mutex.lock()
            availableMetaAccounts = availableMetaAccounts.applying(changes: mappedChanges)
            mutex.unlock()
        case let .failure(error):
            logger?.error("Failed to fetch all wallets: \(error.localizedDescription)")
        }
    }
    
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

enum MultisigPendingOperationsSyncError: Error {
    case noChainMatchingMultisigAccount
    case multisigAccountUnavailable
    case localPendingOperationUnavailable
}
