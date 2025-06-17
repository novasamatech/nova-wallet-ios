import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultisigCallDataSyncServiceProtocol {
    func setup(with chains: [ChainModel])
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
        blockQueryFactory: BlockEventsQueryFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.calldata.sync.service"),
        logger: LoggerProtocol
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
    
    func createCallExtractionWrapper(
        for event: MultisigEvent,
        at blockHash: Data,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<JSON> {
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
        
        let callExtractionOperation = ClosureOperation<JSON> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let blockDetails = try blockQueryWrapper.targetOperation.extractNoCancellableResultData()
            
            guard let callData = blockDetails.extrinsicsWithEvents.first(
                where: { $0.extrinsicHash == event.callHash }
            )?.extrinsicData else {
                throw MultisigCallDataSyncError.extrinsicParsingFailed
            }
            
            let decodedCall = try self.extractDecodedCall(
                from: callData,
                using: codingFactory
            )
            
            return decodedCall
        }
        
        callExtractionOperation.addDependency(codingFactoryOperation)
        callExtractionOperation.addDependency(blockQueryWrapper.targetOperation)
        
        return CompoundOperationWrapper(
            targetOperation: callExtractionOperation,
            dependencies: [codingFactoryOperation] + blockQueryWrapper.allOperations)
    }
    
    func processEvent(
        _ event: MultisigEvent,
        at blockHash: Data,
        chainId: ChainModel.Id
    ) {
        let extractionWrapper = createCallExtractionWrapper(
            for: event,
            at: blockHash,
            chainId: chainId
        )
        
        execute(
            wrapper: extractionWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(call):
                let key = Multisig.PendingOperation.Key(
                    callHash: event.callHash,
                    chainId: chainId,
                    multisigAccountId: event.accountId
                )
                
                self?.cachedCallData.state.store(value: call, for: key)
            case let .failure(error):
                self?.logger.error("Failed to fetch block details: \(error.localizedDescription)")
            }
        }
    }
    
    func extractDecodedCall(
        from extrinsicData: Data,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> JSON {
        let decoder = try codingFactory.createDecoder(from: extrinsicData)
        let context = codingFactory.createRuntimeJsonContext()
        let decodedExtrinsic: Extrinsic = try decoder.read(
            of: GenericType.extrinsic.name,
            with: context.toRawContext()
        )
        
        return decodedExtrinsic.call
    }
}

// MARK: - MultisigEventsSubscriber

extension MultisigCallDataSyncService: MultisigEventsSubscriber {
    func didReceive(
        event: MultisigEvent,
        blockHash: Data,
        chainId: ChainModel.Id
    ) {
        guard availableMetaAccounts.contains(
            where: { $0.multisigAccount?.multisig?.accountId == event.accountId }
        ) else { return }
        
        processEvent(
            event,
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
            logger.error("Failed to fetch all wallets: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

enum MultisigCallDataSyncError: Error {
    case extrinsicParsingFailed
    case chainConnectionUnavailable
    case runtimeUnavailable
}
