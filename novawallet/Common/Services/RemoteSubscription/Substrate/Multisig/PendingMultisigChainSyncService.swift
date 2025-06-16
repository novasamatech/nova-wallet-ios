import Foundation
import Operation_iOS

protocol PendingMultisigChainSyncServiceProtocol: SyncServiceProtocol {}

final class PendingMultisigChainSyncService: BaseSyncService, PendingMultisigChainSyncServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    private let pendingOperationsRepository: InMemoryDataProviderRepository<Multisig.PendingOperation>
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    
    private let cancellableSyncStore = CancellableCallStore()
    
    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol,
        repositoryCachingFactory: InMemoryRepositoryCachingFactory,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.chain.sync.service")
    ) {
        self.wallet = wallet
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.remoteOperationUpdateService = remoteOperationUpdateService
        
        self.pendingOperationsRepository = repositoryCachingFactory.createInMemoryRepository(
            cacheSettings: .useCache
        )
        
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
        
        let fetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())
        
        let mapOperation = ClosureOperation<Void> { [weak self] in
            let pendingOperations = try fetchOperation.extractNoCancellableResultData()
                .filter { $0.chainId == self?.chain.chainId }
            
            pendingOperations.forEach {
                self?.remoteOperationUpdateService.clearSubscription(for: $0.multisigAccountId)
            }
        }
        
        mapOperation.addDependency(fetchOperation)
        
        let wrapper = CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
    }
}

// MARK: - Private

private extension PendingMultisigChainSyncService {
    func createSyncUpWrapper(
        dependingOn remoteFetchWrapper: CompoundOperationWrapper<[CallHash: Multisig.PendingOperation]>
    ) -> CompoundOperationWrapper<Void> {
        let localFetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())
        
        let diffOperation = ClosureOperation<CallHashChanges> {
            let oldCallHashes = try localFetchOperation
                .extractNoCancellableResultData()
                .compactMap { $0.callHash }
            
            let updatedCallHashes = try remoteFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .map { $0.value.callHash }
            
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
                try remoteFetchWrapper.targetOperation.extractNoCancellableResultData().map { $0.value }
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
            dependencies:dependencies
        )
    }
    
    func createManageSubscriptionsOperation(
        callHashesClosure: @escaping () throws -> Set<CallHash>
    ) -> BaseOperation<Void> {
        ClosureOperation<Void> { [weak self] in
            guard
                let self,
                let multisig = wallet.multisigAccount?.multisig
            else { throw BaseOperationError.parentOperationCancelled }
            
            try remoteOperationUpdateService.setupSubscription(
                subscriber: self,
                for: multisig.accountId,
                callHashes: try callHashesClosure(),
                chainId: chain.chainId
            )
        }
    }
    
    func createPendingOperationsWrapper() -> CompoundOperationWrapper<[CallHash: Multisig.PendingOperation]> {
        guard let multisigContext = wallet.multisigAccount?.multisig else {
            return .createWithError(MultisigPendingOperationsSyncError.multisigAccountUnavailable)
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
            }
        )

        callDataFetchWrapper.addDependency(wrapper: callHashFetchWrapper)

        let mapOperation = ClosureOperation<[CallHash: Multisig.PendingOperation]> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }
            
            let callHashes = try callHashFetchWrapper.targetOperation.extractNoCancellableResultData()
            let callData = try callDataFetchWrapper.targetOperation.extractNoCancellableResultData()

            return callHashes.reduce(into: [:]) { acc, keyValue in
                let matchingCallData = callData[keyValue.key]

                let pendingOperation = Multisig.PendingOperation(
                    call: nil,
                    callHash: keyValue.key,
                    multisigAccountId: multisigContext.accountId,
                    signatory: multisigContext.signatory,
                    chainId: self.chain.chainId,
                    multisigDefinition: keyValue.value
                )

                acc[keyValue.key] = pendingOperation
            }
        }

        mapOperation.addDependency(callDataFetchWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: callHashFetchWrapper.allOperations + callDataFetchWrapper.allOperations
        )
    }

    func createCallDataFetchWrapper(
        callHashesClosure: @escaping () throws -> Set<CallHash>
    ) -> CompoundOperationWrapper<[CallHash: CallData]> {
        OperationCombiningService.compoundNonOptionalWrapper(
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
        let localFetchOperation = pendingOperationsRepository.fetchOperation(
            by: callHash.toHexString(),
            options: .init()
        )
        
        let updateOperation = ClosureOperation<Multisig.PendingOperation> {
            guard let localPendingOperation = try localFetchOperation.extractNoCancellableResultData() else {
                throw MultisigPendingOperationsSyncError.localPendingOperationUnavailable
            }
            
            return localPendingOperation.replaicingDefinition(with: multisigDefinition)
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
            Set(try fetchOperation.extractNoCancellableResultData().compactMap { $0.callHash })
        }
        
        fetchOperation.addDependency(removeOperation)
        manageSubscriptionsOperation.addDependency(fetchOperation)
        
        let operations = [removeOperation, fetchOperation, manageSubscriptionsOperation]
        
        operationQueue.addOperations(operations, waitUntilFinished: false)
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
