import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallDataSyncServiceProtocol {
    func addSyncing(for chain: ChainModel)
    func stopSyncing(for chainId: ChainModel.Id)
    func startSyncUp()
    func stopSyncUp()
}

final class MultisigCallDataSyncService: AnyProviderAutoCleaning {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let chainRegistry: ChainRegistryProtocol
    private let callFetchFactory: MultisigCallFetchFactoryProtocol
    private let eventsUpdatingService: MultisigEventsUpdatingServiceProtocol
    private let pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol

    private var metaAccountsProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var availableChains: [ChainModel.Id: ChainModel] = [:]

    private var availableMetaAccounts: [MetaAccountModel] = [] {
        didSet {
            guard oldValue != availableMetaAccounts else { return }

            if oldValue.isEmpty, !availableMetaAccounts.isEmpty {
                updateSubscriptionsIfNeeded()
            } else if availableMetaAccounts.isEmpty {
                stopSyncUp()
            }
        }
    }

    init(
        chainRegistry: ChainRegistryProtocol,
        callFetchFactory: MultisigCallFetchFactoryProtocol,
        eventsUpdatingService: MultisigEventsUpdatingServiceProtocol,
        pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.callFetchFactory = callFetchFactory
        self.eventsUpdatingService = eventsUpdatingService
        self.pendingOperationsRepository = pendingOperationsRepository
        self.chainRegistry = chainRegistry
        self.operationManager = operationManager
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigCallDataSyncService {
    func updateSubscriptionsIfNeeded() {
        let availableChainIds = Set(availableChains.keys)
        let subscribedChainIds = eventsUpdatingService.subscribedChainIds

        let chainsToSubscribe = availableChainIds
            .subtracting(subscribedChainIds)
            .compactMap { availableChains[$0] }

        chainsToSubscribe.forEach { setupSubscription(to: $0) }
    }

    func setupSubscription(to chain: ChainModel) {
        eventsUpdatingService.setupSubscription(
            for: chain.chainId,
            subscriber: self
        )
    }

    func subscribeMetaAccounts() {
        clear(streamableProvider: &metaAccountsProvider)

        metaAccountsProvider = subscribeAllWalletsProvider()
    }
    
    func updatePendingOperations(using callData:[Multisig.PendingOperation.Key: MultisigCallOrHash]) {
        let wrapper = createUpdatePendingOperationsWrapper(using: callData)

        operationManager.enqueue(
            operations: wrapper.allOperations,
            in: .sync
        )
    }
    
    func createUpdatePendingOperationsWrapper(
        using callData: [Multisig.PendingOperation.Key: MultisigCallOrHash]
    ) -> CompoundOperationWrapper<Void> {
        let fetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())
        
        let updateOperation = pendingOperationsRepository.saveOperation(
            {
                let persistedOperations: [Multisig.PendingOperation.Key: Multisig.PendingOperation]
                persistedOperations = try fetchOperation.extractNoCancellableResultData()
                    .reduce(into: [:]) { $0[$1.createKey()] = $1 }
                
                let updates: [Multisig.PendingOperation] = callData.compactMap { keyValue in
                    let call = keyValue.value.call
                    
                    if let persistedOperation = persistedOperations[keyValue.key] {
                        guard let call else { return nil }
                        
                        return persistedOperation.replacingCall(with: call)
                    } else {
                        return Multisig.PendingOperation(
                            call: call,
                            callHash: keyValue.key.callHash,
                            multisigAccountId: keyValue.key.multisigAccountId,
                            signatory: keyValue.key.signatoryAccountId,
                            chainId: keyValue.key.chainId,
                            multisigDefinition: nil
                        )
                    }
                }
                
                return updates
            },
            { [] }
        )
        
        updateOperation.addDependency(fetchOperation)
        
        return CompoundOperationWrapper(
            targetOperation: updateOperation,
            dependencies: [fetchOperation]
        )
    }

    func processEvents(
        _ events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) {
        let extractionWrapper = callFetchFactory.createCallFetchWrapper(
            for: events,
            at: blockHash,
            chainId: chainId
        )
        
        extractionWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                let calls = try extractionWrapper.targetOperation.extractNoCancellableResultData()
                self?.updatePendingOperations(using: calls)
            } catch {
                self?.logger.error("Failed to fetch block details: \(error)")
            }
            
        }

        operationManager.enqueue(
            operations: extractionWrapper.allOperations,
            in: .transient
        )
    }
}

// MARK: - MultisigCallDataSyncServiceProtocol

extension MultisigCallDataSyncService: MultisigCallDataSyncServiceProtocol {
    func startSyncUp() {
        mutex.lock()
        defer { mutex.unlock() }
        
        subscribeMetaAccounts()
    }
    
    func addSyncing(for chain: ChainModel) {
        mutex.lock()
        defer { mutex.unlock() }

        guard availableChains[chain.chainId] == nil else { return }

        availableChains[chain.chainId] = chain

        guard !availableMetaAccounts.isEmpty else { return }

        setupSubscription(to: chain)
    }

    func stopSyncing(for chainId: ChainModel.Id) {
        mutex.lock()
        defer { mutex.unlock() }

        guard availableChains[chainId] != nil else { return }

        availableChains[chainId] = nil
        eventsUpdatingService.clearSubscription(for: chainId)
    }

    func stopSyncUp() {
        mutex.lock()
        defer { mutex.unlock() }
        
        clear(streamableProvider: &metaAccountsProvider)
        eventsUpdatingService.clearAllSubscriptions()
        availableChains = [:]
        availableMetaAccounts = []
    }
}

// MARK: - MultisigEventsSubscriber

extension MultisigCallDataSyncService: MultisigEventsSubscriber {
    func didReceive(
        events: [MultisigEvent],
        blockHash: Data,
        chainId: ChainModel.Id
    ) {
        mutex.lock()
        defer { mutex.unlock() }
        
        let availableAccountIds = Set(availableMetaAccounts.compactMap { $0.multisigAccount?.multisig?.accountId })
        let relevantEvents = events.filter { availableAccountIds.contains($0.accountId) }

        guard !relevantEvents.isEmpty else { return }

        processEvents(
            relevantEvents,
            at: blockHash,
            chainId: chainId
        )
    }
}

// MARK: - WalletListLocalStorageSubscriber

extension MultisigCallDataSyncService: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        mutex.lock()
        defer { mutex.unlock() }
        
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

            availableMetaAccounts = availableMetaAccounts.applying(changes: mappedChanges)
        case let .failure(error):
            logger.error("Failed to fetch all wallets: \(error)")
        }
    }
}
