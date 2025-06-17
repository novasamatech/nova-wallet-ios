import Foundation
import SubstrateSdk
import Operation_iOS

protocol PendingMultisigChainSyncServiceProtocol: SyncServiceProtocol {
    func updatePendingOperationsCallData(
        using knownCallData: [Multisig.PendingOperation.Key: JSON]
    )
}

final class PendingMultisigChainSyncService: BaseSyncService {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    private let pendingOperationsRepository: InMemoryDataProviderRepository<Multisig.PendingOperation>
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var realTimeCallData: [Multisig.PendingOperation.Key: JSON] = [:]

    private let cancellableSyncStore = CancellableCallStore()

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol,
        repositoryCachingFactory: InMemoryRepositoryCachingFactory,
        knownCallData: [Multisig.PendingOperation.Key: JSON],
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.chain.sync.service")
    ) {
        self.wallet = wallet
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.remoteOperationUpdateService = remoteOperationUpdateService

        pendingOperationsRepository = repositoryCachingFactory.createInMemoryRepository(
            cacheSettings: .useCache
        )
        realTimeCallData = knownCallData.filter {
            $0.key.chainId == chain.chainId &&
                $0.key.multisigAccountId == wallet.multisigAccount?.multisig?.accountId
        }

        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    override func performSyncUp() {
        let syncUpWrapper = createSyncUpWrapper(dependingOn: createPendingOperationsWrapper())

        executeCancellable(
            wrapper: syncUpWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableSyncStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .failure(error):
                logger.error("Failed to sync pending operations: \(error), chainId: \(chain.chainId)")
            default:
                break
            }
        }
    }

    override func stopSyncUp() {
        cancellableSyncStore.cancel()
        remoteOperationUpdateService.clearAllSubscriptions()
    }
}

// MARK: - Private

private extension PendingMultisigChainSyncService {
    func createSyncUpWrapper(
        dependingOn remoteFetchWrapper: CompoundOperationWrapper<[Multisig.PendingOperation.Key: Multisig.PendingOperation]>
    ) -> CompoundOperationWrapper<Void> {
        let localFetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let diffOperation = ClosureOperation<CallHashChanges> {
            let oldCallHashes = try localFetchOperation
                .extractNoCancellableResultData()
                .compactMap(\.callHash)

            let updatedCallHashes = try remoteFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .map(\.value.callHash)

            let updatedHashSet = Set(updatedCallHashes)
            let oldHashSet = Set(oldCallHashes)

            return CallHashChanges(
                allCallHashes: updatedHashSet,
                removedCallHashes: oldHashSet.subtracting(updatedHashSet)
            )
        }

        diffOperation.addDependency(remoteFetchWrapper.targetOperation)
        diffOperation.addDependency(localFetchOperation)

        let saveOperation = pendingOperationsRepository.saveOperation(
            {
                try remoteFetchWrapper.targetOperation.extractNoCancellableResultData().map(\.value)
            },
            { try diffOperation.extractNoCancellableResultData().removedCallHashes.map { $0.toHexString() } }
        )

        saveOperation.addDependency(diffOperation)

        let manageSubscriptionsOperation = createManageSubscriptionsOperation {
            try diffOperation.extractNoCancellableResultData().allCallHashes
        }

        manageSubscriptionsOperation.addDependency(saveOperation)

        let dependencies = remoteFetchWrapper.allOperations
            + localFetchOperation.allOperations
            + [diffOperation, saveOperation]

        return CompoundOperationWrapper(
            targetOperation: manageSubscriptionsOperation,
            dependencies: dependencies
        )
    }

    func createManageSubscriptionsOperation(
        callHashesClosure: @escaping () throws -> Set<CallHash>
    ) -> BaseOperation<Void> {
        ClosureOperation<Void> { [weak self] in
            let callHashes = try callHashesClosure()

            guard
                let self,
                let multisig = wallet.multisigAccount?.multisig
            else { throw BaseOperationError.parentOperationCancelled }

            try remoteOperationUpdateService.setupSubscription(
                subscriber: self,
                for: multisig.accountId,
                callHashes: callHashes,
                chainId: chain.chainId
            )
        }
    }

    func createPendingOperationsWrapper() -> CompoundOperationWrapper<[Multisig.PendingOperation.Key: Multisig.PendingOperation]> {
        guard let multisigContext = wallet.multisigAccount?.multisig else {
            return .createWithError(MultisigPendingOperationsSyncError.multisigAccountUnavailable)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return .createWithError(MultisigCallDataSyncError.runtimeUnavailable)
        }

        let callHashFetchWrapper = createCallHashFetchWrapper()
        let callDataFetchWrapper = createCallDataFetchWrapper(
            callHashesClosure: {
                Set(
                    try callHashFetchWrapper
                        .targetOperation
                        .extractNoCancellableResultData()
                        .keys
                )
            },
            runtimeProvider: runtimeProvider
        )

        callDataFetchWrapper.addDependency(wrapper: callHashFetchWrapper)

        let mapOperation = ClosureOperation<[Multisig.PendingOperation.Key: Multisig.PendingOperation]> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let callHashes = try callHashFetchWrapper.targetOperation.extractNoCancellableResultData()
            let fetchedCallData = try callDataFetchWrapper.targetOperation.extractNoCancellableResultData()

            return callHashes.reduce(into: [:]) { acc, keyValue in
                let callHash = keyValue.key
                let definition = keyValue.value
                let operationKey = Multisig.PendingOperation.Key(
                    callHash: callHash,
                    chainId: self.chain.chainId,
                    multisigAccountId: multisigContext.accountId
                )
                let matchingCallData = if let realTimeCall = self.realTimeCallData[operationKey] {
                    realTimeCall
                } else {
                    fetchedCallData[callHash]
                }

                let pendingOperation = Multisig.PendingOperation(
                    call: matchingCallData,
                    callHash: callHash,
                    multisigAccountId: multisigContext.accountId,
                    signatory: multisigContext.signatory,
                    chainId: self.chain.chainId,
                    multisigDefinition: definition
                )

                acc[operationKey] = pendingOperation
            }
        }

        mapOperation.addDependency(callDataFetchWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: callHashFetchWrapper.allOperations + callDataFetchWrapper.allOperations
        )
    }

    func createCallDataFetchWrapper(
        callHashesClosure: @escaping () throws -> Set<CallHash>,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[CallHash: JSON]> {
        let fetchWrapper: CompoundOperationWrapper<[CallHash: CallData]>
        fetchWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let callHashes = try callHashesClosure()

            guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
                return .createWithResult([:])
            }

            let remoteCallDataFetchFactory = SubqueryMultisigsOperationFactory(url: apiURL)

            let callDataFetchOperation = remoteCallDataFetchFactory.createFetchCallDataOperation(for: callHashes)

            return CompoundOperationWrapper(targetOperation: callDataFetchOperation)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<[CallHash: JSON]> { [weak self] in
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let fetchResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return try fetchResult.compactMapValues {
                try self?.extractDecodedCall(from: $0, using: codingFactory)
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)
        mapOperation.addDependency(codingFactoryOperation)

        return fetchWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mapOperation)
    }

    func createCallHashFetchWrapper() -> CompoundOperationWrapper<[CallHash: Multisig.MultisigDefinition]> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        guard let multisigAccountId = wallet.multisigAccount?.multisig?.accountId else {
            return .createWithError(MultisigPendingOperationsSyncError.multisigAccountUnavailable)
        }

        return pendingCallHashesOperationFactory.fetchPendingOperations(
            for: multisigAccountId,
            connection: connection,
            runtimeProvider: runtimeProvider
        )
    }

    func updateDefinition(
        for callHash: CallHash,
        multisigDefinition: Multisig.MultisigDefinition
    ) {
        guard let multisigContext = wallet.multisigAccount?.multisig else {
            return
        }

        let key = Multisig.PendingOperation.Key(
            callHash: callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigContext.accountId
        )
        let localFetchOperation = pendingOperationsRepository.fetchOperation(
            by: key.stringValue(),
            options: .init()
        )

        let updateOperation = ClosureOperation<Multisig.PendingOperation> {
            if let localPendingOperation = try? localFetchOperation.extractNoCancellableResultData() {
                localPendingOperation.replaicingDefinition(with: multisigDefinition)
            } else {
                Multisig.PendingOperation(
                    call: nil,
                    callHash: callHash,
                    multisigAccountId: multisigContext.accountId,
                    signatory: multisigContext.signatory,
                    chainId: self.chain.chainId,
                    multisigDefinition: multisigDefinition
                )
            }
        }

        let saveOperation = pendingOperationsRepository.saveOperation(
            { [try updateOperation.extractNoCancellableResultData()] },
            { [] }
        )

        updateOperation.addDependency(localFetchOperation)
        saveOperation.addDependency(updateOperation)

        let operations = [localFetchOperation, updateOperation, saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    func stopSyncing(callHash: CallHash) {
        let removeOperation = pendingOperationsRepository.saveOperation(
            { [] },
            { [callHash.toHexString()] }
        )
        let fetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let manageSubscriptionsOperation = createManageSubscriptionsOperation {
            Set(try fetchOperation.extractNoCancellableResultData().compactMap(\.callHash))
        }

        fetchOperation.addDependency(removeOperation)
        manageSubscriptionsOperation.addDependency(fetchOperation)

        let operations = [removeOperation, fetchOperation, manageSubscriptionsOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    func processNewCallDataWrapper(
        _ callData: [Multisig.PendingOperation.Key: JSON],
        multisigContext: DelegatedAccount.MultisigAccountModel
    ) -> CompoundOperationWrapper<Void> {
        let fetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let updateOperation = ClosureOperation<[Multisig.PendingOperation.Key: Multisig.PendingOperation]> { [weak self] in
            try fetchOperation.extractNoCancellableResultData()
                .filter {
                    $0.chainId == self?.chain.chainId &&
                        $0.multisigAccountId == multisigContext.accountId
                }
                .reduce(into: [:]) { acc, operation in
                    let key = operation.createKey()

                    if let call = callData[key] {
                        acc[operation.createKey()] = operation.replacingCall(with: call)
                    } else {
                        acc[operation.createKey()] = operation
                    }
                }
        }

        let saveOperation = pendingOperationsRepository.saveOperation(
            { try updateOperation.extractNoCancellableResultData().map(\.value) },
            { [] }
        )

        let updateSubscriptionsWrapper: CompoundOperationWrapper<Void>
        updateSubscriptionsWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { return .createWithResult(()) }

            let knownCallHashes = Set(try updateOperation.extractNoCancellableResultData().keys.map(\.callHash))
            let newCallHashes = Set(callData.map(\.key.callHash)).subtracting(knownCallHashes)

            guard !newCallHashes.isEmpty else {
                return .createWithResult(())
            }

            let manageSubscriptionsOperation = createManageSubscriptionsOperation {
                knownCallHashes.union(newCallHashes)
            }

            return CompoundOperationWrapper(targetOperation: manageSubscriptionsOperation)
        }

        updateOperation.addDependency(fetchOperation)
        saveOperation.addDependency(updateOperation)
        updateSubscriptionsWrapper.addDependency(operations: [saveOperation])

        return updateSubscriptionsWrapper.insertingHead(
            operations: [fetchOperation, updateOperation, saveOperation]
        )
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

// MARK: - PendingMultisigChainSyncServiceProtocol

extension PendingMultisigChainSyncService: PendingMultisigChainSyncServiceProtocol {
    func updatePendingOperationsCallData(using knownCallData: [Multisig.PendingOperation.Key: JSON]) {
        guard let multisigContext = wallet.multisigAccount?.multisig else {
            return
        }

        mutex.lock()
        let relevantCallData = knownCallData.filter {
            $0.key.chainId == chain.chainId &&
                $0.key.multisigAccountId == multisigContext.accountId
        }
        realTimeCallData.merge(relevantCallData, uniquingKeysWith: { $1 })
        mutex.unlock()

        let processCallDataWrapper = processNewCallDataWrapper(
            realTimeCallData,
            multisigContext: multisigContext
        )

        operationQueue.addOperations(
            processCallDataWrapper.allOperations,
            waitUntilFinished: false
        )
    }
}

// MARK: - MultisigPendingOperationsSubscriber

extension PendingMultisigChainSyncService: MultisigPendingOperationsSubscriber {
    func didReceiveUpdate(
        callHash: CallHash,
        multisigDefinition: Multisig.MultisigDefinition?
    ) {
        if let multisigDefinition {
            updateDefinition(for: callHash, multisigDefinition: multisigDefinition)
        } else {
            stopSyncing(callHash: callHash)
        }
    }
}

private struct CallHashChanges {
    let allCallHashes: Set<CallHash>
    let removedCallHashes: Set<CallHash>
}
