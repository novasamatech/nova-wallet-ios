import Foundation
import Operation_iOS

protocol MultisigPendingOperationsSyncServiceProtocol: ApplicationServiceProtocol {}

class MultisigPendingOperationsSyncService {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let chainRegistry: ChainRegistryProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private let cancellableSyncStore = CancellableCallStore()

    private var pendingOperations: [CallHash: Multisig.PendingOperation] = [:]

    private var metaAccountsDataProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var multisigMetaAccounts: [MetaAccountModel] = [] {
        didSet {
            if multisigMetaAccounts != oldValue {
                updatePendingOperationsList()
            }
        }
    }

    init(
        chainRegistry: ChainRegistryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.sync"),
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.chainRepository = chainRepository
        self.remoteOperationUpdateService = remoteOperationUpdateService
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
    }

    deinit {
        cancellableSyncStore.cancel()
    }
}

// MARK: - Private

private extension MultisigPendingOperationsSyncService {
    func performSetup() {
        metaAccountsDataProvider = subscribeAllWalletsProvider()
    }

    func updatePendingOperationsList() {
        cancellableSyncStore.cancel()

        let chainsFetchOperation = chainRepository.fetchAllOperation(with: .init())

        let fetchCallHashesOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            return multisigMetaAccounts.map { multisig in
                self.createPendingOperationsWrapper(
                    for: multisig,
                    dependingOn: chainsFetchOperation
                )
            }
        }.longrunOperation()

        execute(
            operation: fetchCallHashesOperation,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableSyncStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(dict):
                let merged = dict.reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { $1 }) }

                mutex.lock()

                let updatedHashes = Set(merged.keys)
                let oldHashes = Set(pendingOperations.keys)
                let newHashes = updatedHashes.subtracting(oldHashes)

                pendingOperations.merge(merged, uniquingKeysWith: { $1 })
                subscribe(newHashes)

                mutex.unlock()
            case let .failure(error):
                logger?.error("Failed to fetch pending operations: \(error)")
            }
        }
    }

    func createPendingOperationsWrapper(
        for multisigMetaAccount: MetaAccountModel,
        dependingOn chainsFetchOperation: BaseOperation<[ChainModel]>
    ) -> CompoundOperationWrapper<[CallHash: Multisig.PendingOperation]> {
        guard let multisigContext = multisigMetaAccount.multisig else {
            return .createWithError(MultisigPendingOperationsSyncError.multisigAccountUnavailable)
        }
        let chainMatchOperation = createMatchChainOperation(
            for: multisigMetaAccount,
            chainsClosure: { try chainsFetchOperation.extractNoCancellableResultData() }
        )
        let callHashFetchWrapper = createCallHashFetchWrapper(
            for: multisigMetaAccount,
            chainIdClosure: { try chainMatchOperation.extractNoCancellableResultData().chainId }
        )
        let callDataFetchWrapper = createCallDataFetchWrapper(
            chainClosure: { try chainMatchOperation.extractNoCancellableResultData() },
            callHashesClosure: {
                Set(
                    try callHashFetchWrapper
                        .targetOperation
                        .extractNoCancellableResultData()
                        .keys
                )
            }
        )

        chainMatchOperation.addDependency(chainsFetchOperation)
        callHashFetchWrapper.addDependency(operations: [chainMatchOperation])
        callDataFetchWrapper.addDependency(operations: [chainMatchOperation])
        callDataFetchWrapper.addDependency(wrapper: callHashFetchWrapper)

        let mapOperation = ClosureOperation<[CallHash: Multisig.PendingOperation]> {
            let chain = try chainMatchOperation.extractNoCancellableResultData()
            let callHashes = try callHashFetchWrapper.targetOperation.extractNoCancellableResultData()
            let callData = try callDataFetchWrapper.targetOperation.extractNoCancellableResultData()

            return callHashes.reduce(into: [:]) { acc, keyValue in
                let matchingCallData = callData[keyValue.key]

                let pendingOperation = Multisig.PendingOperation(
                    call: nil,
                    callHash: keyValue.key,
                    multisigAccountId: multisigContext.accountId,
                    signatory: multisigContext.signatory,
                    chainId: chain.chainId,
                    multisigDefinition: keyValue.value
                )

                acc[keyValue.key] = pendingOperation
            }
        }

        mapOperation.addDependency(chainMatchOperation)
        mapOperation.addDependency(callHashFetchWrapper.targetOperation)
        mapOperation.addDependency(callDataFetchWrapper.targetOperation)

        let dependencies = [chainsFetchOperation, chainMatchOperation]
            + callHashFetchWrapper.allOperations
            + callDataFetchWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func createCallDataFetchWrapper(
        chainClosure: @escaping () throws -> ChainModel,
        callHashesClosure: @escaping () throws -> Set<CallHash>
    ) -> CompoundOperationWrapper<[CallHash: CallData]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let chain = try chainClosure()
            let callHashes = try callHashesClosure()

            guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
                return .createWithResult([:])
            }

            let remoteCallDataFetchFactory = SubqueryMultisigsOperationFactory(url: apiURL)

            let callDataFetchOperation = remoteCallDataFetchFactory.createFetchCallDataOperation(for: callHashes)

            return CompoundOperationWrapper(targetOperation: callDataFetchOperation)
        }
    }

    func createCallHashFetchWrapper(
        for multisigMetaAccount: MetaAccountModel,
        chainIdClosure: @escaping () throws -> ChainModel.Id
    ) -> CompoundOperationWrapper<[CallHash: Multisig.MultisigDefinition]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let chainId = try chainIdClosure()

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            guard let multisigAccountId = multisigMetaAccount.multisig?.accountId else {
                throw MultisigPendingOperationsSyncError.multisigAccountUnavailable
            }

            return pendingCallHashesOperationFactory.fetchPendingOperations(
                for: multisigAccountId,
                connection: connection,
                runtimeProvider: runtimeProvider
            )
        }
    }

    func createMatchChainOperation(
        for multisigMetaAccount: MetaAccountModel,
        chainsClosure: @escaping () throws -> [ChainModel]
    ) -> BaseOperation<ChainModel> {
        ClosureOperation {
            let chains: [ChainModel.Id: ChainModel] = try chainsClosure()
                .reduce(into: [:]) { $0[$1.chainId] = $1 }

            let accountRequests = chains.map { $0.value.accountRequest() }
            let accountResponse = accountRequests.compactMap { multisigMetaAccount.fetch(for: $0) }.first

            guard let accountResponse, let chain = chains[accountResponse.chainId] else {
                throw MultisigPendingOperationsSyncError.noChainMatchingMultisigAccount
            }

            return chain
        }
    }

    func subscribe(_ callHashes: Set<CallHash>) {
        let operationsMap: [AccountId: [Multisig.PendingOperation]] = callHashes
            .reduce(into: [:]) { acc, callHash in
                guard let pendingOperation = pendingOperations[callHash] else { return }

                if let operations = acc[pendingOperation.multisigAccountId] {
                    acc[pendingOperation.multisigAccountId] = operations + [pendingOperation]
                } else {
                    acc[pendingOperation.multisigAccountId] = [pendingOperation]
                }
            }

        do {
            try operationsMap.forEach { multisigAccountId, pendingOperations in
                guard let chainId = pendingOperations.first?.chainId else { return }

                let callHashes = pendingOperations.map(\.callHash)

                try remoteOperationUpdateService.setupSubscription(
                    subscriber: self,
                    for: multisigAccountId,
                    callHashes: Set(callHashes),
                    chainId: chainId
                )
            }
        } catch {
            logger?.error("Failed to subscribe to remote operations: \(error)")
        }
    }

    func stopSyncing(callHash: CallHash) {
        mutex.lock()
        defer { mutex.unlock() }

        guard let pendingOperation = pendingOperations[callHash] else {
            return
        }

        pendingOperations[callHash] = nil

        let operationsForAccountId = pendingOperations.filter {
            $0.value.multisigAccountId == pendingOperation.multisigAccountId
        }
        let updatedCallHashes = operationsForAccountId.keys

        remoteOperationUpdateService.clearSubscription(for: pendingOperation.multisigAccountId)

        subscribe(Set(updatedCallHashes))
    }
}

// MARK: - MultisigPendingOperationsSyncServiceProtocol

extension MultisigPendingOperationsSyncService: MultisigPendingOperationsSyncServiceProtocol {
    func setup() {
        performSetup()
    }

    func throttle() {
        let callHashes = pendingOperations.keys

        callHashes.forEach { stopSyncing(callHash: $0) }
        metaAccountsDataProvider = nil
    }
}

// MARK: - MultisigPendingOperationsSubscriber

extension MultisigPendingOperationsSyncService: MultisigPendingOperationsSubscriber {
    func didReceiveUpdate(
        callHash: CallHash,
        multisigDefinition: Multisig.MultisigDefinition?
    ) {
        if let multisigDefinition, let pendingOperation = pendingOperations[callHash] {
            mutex.lock()
            pendingOperations[callHash] = pendingOperation.replaicingDefinition(with: multisigDefinition)
            mutex.unlock()
        } else {
            stopSyncing(callHash: callHash)
        }
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

            multisigMetaAccounts = multisigMetaAccounts.applying(changes: mappedChanges)
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}

enum MultisigPendingOperationsSyncError: Error {
    case noChainMatchingMultisigAccount
    case multisigAccountUnavailable
}
