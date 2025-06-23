import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallDataSyncServiceProtocol {
    func addSyncing(for chain: ChainModel)
    func stopSyncing(for chainId: ChainModel.Id)
    func stopSyncUp()
    func addObserver(
        _ observer: MultisigCallDataObserver,
        sendOnSubscription: Bool
    )
}

final class MultisigCallDataSyncService: AnyProviderAutoCleaning {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let chainRegistry: ChainRegistryProtocol
    private let callFetchFactory: MultisigCallFetchFactoryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol

    private var metaAccountsProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var availableChains: [ChainModel.Id: ChainModel] = [:]
    private var eventsSubscriptions: [ChainModel.Id: MultisigEventsSubscription] = [:]
    private var cachedCallData: CallDataCache = .init(state: .init())

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
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.calldata.sync.service"),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.callFetchFactory = callFetchFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        subscribeMetaAccounts()
    }
}

// MARK: - Private

private extension MultisigCallDataSyncService {
    func updateSubscriptionsIfNeeded() {
        let availableChainIds = Set(availableChains.keys)
        let subscribedChainIds = Set(eventsSubscriptions.keys)

        let chainsToSubscribe = availableChainIds
            .subtracting(subscribedChainIds)
            .compactMap { availableChains[$0] }

        chainsToSubscribe.forEach { setupSubscription(to: $0) }
    }

    func setupSubscription(to chain: ChainModel) {
        let subscription = MultisigEventsSubscription(
            chainId: chain.chainId,
            chainRegistry: chainRegistry,
            subscriber: self,
            operationQueue: operationQueue,
            workingQueue: workingQueue
        )

        eventsSubscriptions[chain.chainId] = subscription
    }

    func subscribeMetaAccounts() {
        clear(streamableProvider: &metaAccountsProvider)

        metaAccountsProvider = subscribeAllWalletsProvider()
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

        execute(
            wrapper: extractionWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(calls):
                calls.forEach { self?.cachedCallData.state.store(value: $1, for: $0) }
            case let .failure(error):
                self?.logger.error("Failed to fetch block details: \(error)")
            }
        }
    }
}

// MARK: - MultisigCallDataSyncServiceProtocol

extension MultisigCallDataSyncService: MultisigCallDataSyncServiceProtocol {
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
        eventsSubscriptions[chainId] = nil
    }

    func stopSyncUp() {
        clear(streamableProvider: &metaAccountsProvider)
        eventsSubscriptions = [:]
        availableChains = [:]
        availableMetaAccounts = []
    }

    func addObserver(
        _ observer: any MultisigCallDataObserver,
        sendOnSubscription: Bool
    ) {
        cachedCallData.addObserver(
            with: observer,
            sendStateOnSubscription: sendOnSubscription,
            queue: workingQueue
        ) { oldValue, newValue in
            observer.didReceive(newCallData: newValue.newItems(after: oldValue))
        }
    }
}

// MARK: - MultisigEventsSubscriber

extension MultisigCallDataSyncService: MultisigEventsSubscriber {
    func didReceive(
        events: [MultisigEvent],
        blockHash: Data,
        chainId: ChainModel.Id
    ) {
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
            logger.error("Failed to fetch all wallets: \(error)")
        }
    }
}

// MARK: - Errors

enum MultisigCallDataSyncError: Error {
    case extrinsicParsingFailed
    case chainUnavailable
    case chainConnectionUnavailable
    case runtimeUnavailable
}

// MARK: - Private types

private typealias CallDataCache = Observable<
    ObservableInMemoryCache<
        Multisig.PendingOperation.Key,
        MultisigCallOrHash
    >
>
