import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallDataSyncServiceProtocol {
    func setup(with chains: [ChainModel])
    func stopSyncUp()
    func addObserver(
        _ observer: MultisigCallDataObserver,
        sendOnSubscription: Bool
    )
}

private typealias CallDataCache = Observable<
    ObservableInMemoryCache<
        Multisig.PendingOperation.Key,
        JSON
    >
>

final class MultisigCallDataSyncService {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let chainRegistry: ChainRegistryProtocol
    private let substrateStorageFacade: StorageFacadeProtocol
    private let blockQueryFactory: BlockEventsQueryFactoryProtocol
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
                setupCallDataSubscriptions()
            } else if availableMetaAccounts.isEmpty {
                stopSyncUp()
            }
        }
    }

    init(
        chainRegistry: ChainRegistryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        blockQueryFactory: BlockEventsQueryFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.calldata.sync.service"),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.substrateStorageFacade = substrateStorageFacade
        self.blockQueryFactory = blockQueryFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigCallDataSyncService {
    func setupCallDataSubscriptions() {
        availableChains.values.forEach { chain in
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

    func createCallExtractionWrapper(
        for events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<[Multisig.PendingOperation.Key: JSON]> {
        guard let chain = availableChains[chainId] else {
            return .createWithError(MultisigCallDataSyncError.chainUnavailable)
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return .createWithError(MultisigCallDataSyncError.chainConnectionUnavailable)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            return .createWithError(MultisigCallDataSyncError.runtimeUnavailable)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let blockQueryWrapper = blockQueryFactory.queryBlockDetailsWrapper(
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        let callExtractionOperation = ClosureOperation<[Multisig.PendingOperation.Key: JSON]> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let blockDetails = try blockQueryWrapper.targetOperation.extractNoCancellableResultData()

            return events.reduce(into: [:]) { acc, event in
                let extractedCallData = self.extractMultisigCallData(
                    from: blockDetails,
                    matching: event,
                    chainId: chainId,
                    using: codingFactory
                )

                acc.merge(extractedCallData, uniquingKeysWith: { $1 })
            }
        }

        callExtractionOperation.addDependency(codingFactoryOperation)
        callExtractionOperation.addDependency(blockQueryWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: callExtractionOperation,
            dependencies: [codingFactoryOperation] + blockQueryWrapper.allOperations
        )
    }

    func extractMultisigCallData(
        from blockDetails: SubstrateBlockDetails,
        matching multisigEvent: MultisigEvent,
        chainId: ChainModel.Id,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> [Multisig.PendingOperation.Key: JSON] {
        guard let chain = availableChains[chainId] else {
            return [:]
        }

        let extrinsicProcessor = ExtrinsicProcessor(
            accountId: multisigEvent.accountId,
            chain: chain
        )

        let context = codingFactory.createRuntimeJsonContext().toRawContext()

        return blockDetails.extrinsicsWithEvents.enumerated().reduce(into: [:]) { acc, indexedExtrinsicsWithEvents in
            let index = indexedExtrinsicsWithEvents.offset
            let extrinsicWithEvents = indexedExtrinsicsWithEvents.element

            guard
                let processingResult = extrinsicProcessor.process(
                    extrinsicIndex: UInt32(index),
                    extrinsicData: extrinsicWithEvents.extrinsicData,
                    eventRecords: extrinsicWithEvents.eventRecords,
                    coderFactory: codingFactory
                ),
                processingResult.callPath.isMultisig
            else { return }

            guard
                let encodedCall = try? JSONEncoder.scaleCompatible(with: context).encode(processingResult.call),
                let callHash = try? StorageHasher.blake256.hash(data: encodedCall),
                multisigEvent.callHash == callHash
            else { return }

            let key = Multisig.PendingOperation.Key(
                callHash: callHash,
                chainId: chainId,
                multisigAccountId: multisigEvent.accountId
            )

            return acc[key] = processingResult.call
        }
    }

    func processEvents(
        _ events: [MultisigEvent],
        at blockHash: Data,
        chainId: ChainModel.Id
    ) {
        let extractionWrapper = createCallExtractionWrapper(
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

    func extractDecodedCall(
        from extrinsicData: Data,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> JSON {
        let decoder = try codingFactory.createDecoder(from: extrinsicData)
        let context = codingFactory.createRuntimeJsonContext()
        let decodedCall: JSON = try decoder.read(
            of: GenericType.call.name,
            with: context.toRawContext()
        )

        return decodedCall
    }
}

// MARK: - MultisigCallDataSyncServiceProtocol

extension MultisigCallDataSyncService: MultisigCallDataSyncServiceProtocol {
    func setup(with chains: [ChainModel]) {
        mutex.lock()
        defer { mutex.unlock() }

        availableChains = chains.reduce(into: [:]) { $0[$1.chainId] = $1 }
        subscribeMetaAccounts()
    }

    func stopSyncUp() {
        metaAccountsProvider = nil
        availableMetaAccounts = []
        eventsSubscriptions = [:]
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
