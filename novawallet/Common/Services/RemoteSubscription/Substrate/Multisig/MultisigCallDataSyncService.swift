import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallDataSyncServiceProtocol {
    func setup(with chains: [ChainModel])
}

private typealias CallDataCache = Observable<ObservableInMemoryCache<CallHash, JSON>>

final class MultisigCallDataSyncService {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    
    private let mutex = NSLock()
    
    private let chainRegistry: ChainRegistryProtocol
    private let substrateStorageFacade: StorageFacadeProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol
    
    private var metaAccountsProvider: StreamableProvider<ManagedMetaAccountModel>?
    
    private var availableChains: [ChainModel] = []
    private var eventsSubscriptions: [ChainModel.Id: MultisigEventsSubscription] = [:]
    private var cachedCallData: CallDataCache = .init(state: .init())
    
    private var availableMetaAccounts: [MetaAccountModel] = [] {
        didSet {
            guard !oldValue.isEmpty, availableMetaAccounts != oldValue else { return }
            setupCallDataSubscriptions()
        }
    }
    
    init(
        chainRegistry: ChainRegistryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.calldata.sync.service"),
        logger: LoggerProtocol
    ) {
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.substrateStorageFacade = substrateStorageFacade
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigCallDataSyncService {
    func setupCallDataSubscriptions() {
        mutex.lock()
        defer { mutex.unlock() }
        
        availableChains.forEach { chain in
            let subscription = MultisigEventsSubscription(
                chainId: chain.chainId,
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                subscriber: self,
                operationQueue: operationQueue,
                workingQueue: workingQueue
            )
            
            eventsSubscriptions[chain.chainId] = subscription
        }
    }
    
    func subscribeMetaAccounts() {
        metaAccountsProvider = subscribeAllWalletsProvider()
    }
}

// MARK: - MultisigCallDataSyncServiceProtocol

extension MultisigCallDataSyncService: MultisigCallDataSyncServiceProtocol {
    func setup(with chains: [ChainModel]) {
        mutex.lock()
        defer { mutex.unlock() }
        
        availableChains = chains
        subscribeMetaAccounts()
    }
}

// MARK: - MultisigEventsSubscriber

extension MultisigCallDataSyncService: MultisigEventsSubscriber {
    func didReceive(
        event: MultisigEvent,
        blockHash: Data
    ) {
        guard availableMetaAccounts.contains(
            where: { $0.multisigAccount?.multisig?.accountId == event.accountId }
        ) else { return }
        
        
    }
}

// MARK: - WalletListLocalStorageSubscriber

extension MultisigCallDataSyncService: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
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
            logger.error("Failed to fetch all wallets: \(error.localizedDescription)")
        }
    }
}
