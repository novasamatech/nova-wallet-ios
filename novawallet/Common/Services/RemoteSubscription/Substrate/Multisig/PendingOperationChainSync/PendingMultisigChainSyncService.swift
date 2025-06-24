import Foundation
import SubstrateSdk
import Operation_iOS

protocol PendingMultisigChainSyncServiceProtocol: SyncServiceProtocol {
    func updatePendingOperations(
        using knownCallData: [Multisig.PendingOperation.Key: MultisigCallOrHash]
    )
}

final class PendingMultisigChainSyncService: BaseSyncService {
    private let multisigAccount: DelegatedAccount.MultisigAccountModel
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    private let pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var realTimeCallData: [Multisig.PendingOperation.Key: JSON] = [:]

    private let cancellableSyncStore = CancellableCallStore()

    init(
        multisigAccount: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol,
        pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>,
        knownCallData: [Multisig.PendingOperation.Key: JSON],
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.chain.sync.service")
    ) {
        self.multisigAccount = multisigAccount
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.remoteOperationUpdateService = remoteOperationUpdateService
        self.pendingOperationsRepository = pendingOperationsRepository

        realTimeCallData = knownCallData.filter {
            $0.key.chainId == chain.chainId &&
                $0.key.multisigAccountId == multisigAccount.accountId
        }

        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    deinit {
        remoteOperationUpdateService.clearSubscription()
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
        remoteOperationUpdateService.clearSubscription()
    }
}

// MARK: - Private

private extension PendingMultisigChainSyncService {
    func createSyncUpWrapper(
        dependingOn remoteFetchWrapper: CompoundOperationWrapper<[Multisig.PendingOperation]>
    ) -> CompoundOperationWrapper<Void> {
        let localFetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let diffOperation = ClosureOperation<CallHashChanges> {
            let oldCallHashes = try localFetchOperation
                .extractNoCancellableResultData()
                .compactMap(\.callHash)

            let updatedCallHashes = try remoteFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()
                .map(\.callHash)

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
                try remoteFetchWrapper.targetOperation.extractNoCancellableResultData()
            },
            {
                try diffOperation.extractNoCancellableResultData().removedCallHashes.map { $0.toHexString() }
            }
        )

        saveOperation.addDependency(diffOperation)

        let manageSubscriptionsOperation = createManageSubscriptionsOperation {
            try diffOperation.extractNoCancellableResultData().allCallHashes
        }

        manageSubscriptionsOperation.addDependency(saveOperation)

        return remoteFetchWrapper
            .insertingHead(operations: [localFetchOperation, diffOperation, saveOperation])
            .insertingTail(operation: manageSubscriptionsOperation)
    }

    func createPendingOperationsWrapper() -> CompoundOperationWrapper<[Multisig.PendingOperation]> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

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

            let mapOperation = ClosureOperation<[Multisig.PendingOperation]> { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                let callHashes = try callHashFetchWrapper.targetOperation.extractNoCancellableResultData()
                let fetchedCallData = try callDataFetchWrapper.targetOperation.extractNoCancellableResultData()

                return callHashes.map { keyValue in
                    let callHash = keyValue.key
                    let operationKey = Multisig.PendingOperation.Key(
                        callHash: callHash,
                        chainId: self.chain.chainId,
                        multisigAccountId: self.multisigAccount.accountId
                    )
                    let matchingCallData = if let realTimeCall = self.realTimeCallData[operationKey] {
                        realTimeCall
                    } else {
                        fetchedCallData[callHash]
                    }

                    return Multisig.PendingOperation(
                        call: matchingCallData,
                        callHash: callHash,
                        multisigAccountId: self.multisigAccount.accountId,
                        signatory: self.multisigAccount.signatory,
                        chainId: self.chain.chainId,
                        multisigDefinition: self.mapDefinition(from: keyValue.value)
                    )
                }
            }

            mapOperation.addDependency(callDataFetchWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: callHashFetchWrapper.allOperations + callDataFetchWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }

    func mapDefinition(
        from onChainMultisigDefinition: MultisigPallet.MultisigDefinition
    ) -> Multisig.MultisigDefinition {
        Multisig.MultisigDefinition(
            timepoint: .init(
                height: onChainMultisigDefinition.timepoint.height,
                index: onChainMultisigDefinition.timepoint.index
            ),
            depositor: onChainMultisigDefinition.depositor,
            approvals: onChainMultisigDefinition.approvals.map(\.wrappedValue)
        )
    }

    func createManageSubscriptionsOperation(
        callHashesClosure: @escaping () throws -> Set<CallHash>
    ) -> BaseOperation<Void> {
        ClosureOperation<Void> { [weak self] in
            let callHashes = try callHashesClosure()

            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            remoteOperationUpdateService.setupSubscription(
                subscriber: self,
                for: multisigAccount.accountId,
                callHashes: callHashes,
                chainId: chain.chainId
            )
        }
    }

    func createCallHashFetchWrapper() -> CompoundOperationWrapper<[CallHash: MultisigPallet.MultisigDefinition]> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            return pendingCallHashesOperationFactory.fetchPendingOperations(
                for: multisigAccount.accountId,
                connection: connection,
                runtimeProvider: runtimeProvider
            )
        } catch {
            return .createWithError(error)
        }
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

    func updateDefinition(
        for callHash: CallHash,
        multisigDefinition: Multisig.MultisigDefinition
    ) {
        let key = Multisig.PendingOperation.Key(
            callHash: callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigAccount.accountId
        )
        let localFetchOperation = pendingOperationsRepository.fetchOperation(
            by: key.stringValue(),
            options: .init()
        )

        let updateOperation = ClosureOperation<Multisig.PendingOperation> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            var pendingOperation = if let localPendingOperation = try? localFetchOperation.extractNoCancellableResultData() {
                localPendingOperation.replaicingDefinition(with: multisigDefinition)
            } else {
                Multisig.PendingOperation(
                    call: nil,
                    callHash: callHash,
                    multisigAccountId: multisigAccount.accountId,
                    signatory: multisigAccount.signatory,
                    chainId: self.chain.chainId,
                    multisigDefinition: multisigDefinition
                )
            }
            
            if let call = realTimeCallData[key] {
                pendingOperation = pendingOperation.replacingCall(with: call)
            }
            
            return pendingOperation
        }

        let saveOperation = pendingOperationsRepository.saveOperation(
            { [try updateOperation.extractNoCancellableResultData()] },
            { [] }
        )

        updateOperation.addDependency(localFetchOperation)
        saveOperation.addDependency(updateOperation)

        let operations = [localFetchOperation, updateOperation, saveOperation]

        operationQueue.addOperations(
            operations,
            waitUntilFinished: false
        )
    }

    func removeOperation(with callHash: CallHash) {
        let key = Multisig.PendingOperation.Key(
            callHash: callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigAccount.accountId
        )
        let removeOperation = pendingOperationsRepository.saveOperation(
            { [] },
            { [key.stringValue()] }
        )

        operationQueue.addOperations(
            [removeOperation],
            waitUntilFinished: false
        )
    }

    func processNewCallDataWrapper(
        _ callData: [Multisig.PendingOperation.Key: MultisigCallOrHash]
    ) -> CompoundOperationWrapper<Void> {
        let fetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let updateOperation = ClosureOperation<[Multisig.PendingOperation]> {
            try fetchOperation.extractNoCancellableResultData()
                .compactMap { operation in
                    if let call = callData[operation.createKey()]?.call {
                        operation.replacingCall(with: call)
                    } else {
                        nil
                    }
                }
        }

        let saveOperation = pendingOperationsRepository.saveOperation(
            { try updateOperation.extractNoCancellableResultData() },
            { [] }
        )

        let updateSubscriptionsWrapper: CompoundOperationWrapper<Void>
        updateSubscriptionsWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { return .createWithResult(()) }

            let operations = try fetchOperation.extractNoCancellableResultData()
            let knownCallHashes = Set(operations.map(\.callHash))
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

        return updateSubscriptionsWrapper
            .insertingHead(operations: [fetchOperation, updateOperation, saveOperation])
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

// MARK: - PendingMultisigChainSyncServiceProtocol

extension PendingMultisigChainSyncService: PendingMultisigChainSyncServiceProtocol {
    func updatePendingOperations(
        using knownCallData: [Multisig.PendingOperation.Key: MultisigCallOrHash]
    ) {
        mutex.lock()
        let relevantCallData = knownCallData.filter {
            $0.key.chainId == chain.chainId &&
                $0.key.multisigAccountId == multisigAccount.accountId
        }
        realTimeCallData.merge(
            relevantCallData.reduce(into: [:]) { $0[$1.key] = $1.value.call },
            uniquingKeysWith: { $1 }
        )
        mutex.unlock()

        guard !relevantCallData.isEmpty else { return }

        let processCallDataWrapper = processNewCallDataWrapper(relevantCallData)

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
        multisigDefinition: MultisigPallet.MultisigDefinition?
    ) {
        if let multisigDefinition {
            updateDefinition(
                for: callHash,
                multisigDefinition: mapDefinition(from: multisigDefinition)
            )
        } else {
            removeOperation(with: callHash)
        }
    }
}

// MARK: - Local types

private struct CallHashChanges {
    let allCallHashes: Set<CallHash>
    let removedCallHashes: Set<CallHash>
}
