import Foundation
import SubstrateSdk
import Operation_iOS

typealias MultisigPendingOperationsMap = [Multisig.PendingOperation.Key: Multisig.PendingOperation]

protocol PendingMultisigLocalStorageSyncServiceProtocol {
    func syncPendingOperations(
        completionBlock: @escaping (_ updatedCallHashes: Set<CallHash>) -> Void
    )

    func updateDefinition(
        for callHash: CallHash,
        _ multisigDefinition: MultisigPallet.MultisigDefinition?
    )
}

final class PendingMultisigLocalStorageSyncService {
    private let multisigAccount: DelegatedAccount.MultisigAccountModel
    private let chain: ChainModel
    private let chainRegistry: ChainRegistryProtocol
    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    private let pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol

    init(
        multisigAccount: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol,
        pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.multisigAccount = multisigAccount
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.remoteOperationUpdateService = remoteOperationUpdateService
        self.pendingOperationsRepository = pendingOperationsRepository
        self.operationManager = operationManager
        self.logger = logger
    }
}

// MARK: - Private

private extension PendingMultisigLocalStorageSyncService {
    func createSyncUpWrapper(
        remotePendingOperations: MultisigPendingOperationsMap
    ) -> CompoundOperationWrapper<Set<CallHash>> {
        let localFetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let diffOperation = ClosureOperation<CallHashChanges> {
            let oldCallHashes = try localFetchOperation
                .extractNoCancellableResultData()
                .compactMap(\.callHash)

            let updatedCallHashes = remotePendingOperations.map(\.key.callHash)

            let updatedHashSet = Set(updatedCallHashes)
            let oldHashSet = Set(oldCallHashes)

            return CallHashChanges(
                allCallHashes: updatedHashSet,
                removedCallHashes: oldHashSet.subtracting(updatedHashSet)
            )
        }

        let updateOperation = pendingOperationsRepository.saveOperation(
            {
                let localPendingOperations = try localFetchOperation
                    .extractNoCancellableResultData()
                    .reduce(into: [:]) { $0[$1.createKey()] = $1 }

                let newItems = remotePendingOperations.filter { localPendingOperations[$0.key] == nil }.values

                let updates: [Multisig.PendingOperation] = localPendingOperations.compactMap { key, local in
                    guard let remote = remotePendingOperations[key] else { return nil }

                    let definitionUpdated = remote.multisigDefinition != local.multisigDefinition
                    let callUpdated = remote.call != nil && local.call == nil

                    guard definitionUpdated || callUpdated else { return nil }

                    var updatedValue = local

                    if definitionUpdated {
                        updatedValue = updatedValue.replacingDefinition(with: remote.multisigDefinition)
                    }
                    if callUpdated {
                        updatedValue = updatedValue.replacingCall(with: remote.call)
                    }

                    return updatedValue
                }

                return newItems + updates
            },
            {
                try diffOperation.extractNoCancellableResultData().removedCallHashes.map { $0.toHexString() }
            }
        )

        let resultOperation = ClosureOperation<Set<CallHash>> {
            try updateOperation.extractNoCancellableResultData()

            return try diffOperation.extractNoCancellableResultData().allCallHashes
        }

        diffOperation.addDependency(localFetchOperation)
        updateOperation.addDependency(diffOperation)
        resultOperation.addDependency(updateOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [localFetchOperation, diffOperation, updateOperation]
        )
    }

    func createPendingOperationsWrapper() -> CompoundOperationWrapper<MultisigPendingOperationsMap> {
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

            let mapOperation: BaseOperation<MultisigPendingOperationsMap>
            mapOperation = ClosureOperation { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                let callHashes = try callHashFetchWrapper.targetOperation.extractNoCancellableResultData()
                let fetchedCallData = try callDataFetchWrapper.targetOperation.extractNoCancellableResultData()

                return callHashes.reduce(into: [:]) { acc, keyValue in
                    let callHash = keyValue.key
                    let operationKey = Multisig.PendingOperation.Key(
                        callHash: callHash,
                        chainId: self.chain.chainId,
                        multisigAccountId: self.multisigAccount.accountId,
                        signatoryAccountId: self.multisigAccount.signatory
                    )

                    acc[operationKey] = Multisig.PendingOperation(
                        call: fetchedCallData[callHash],
                        callHash: callHash,
                        multisigAccountId: self.multisigAccount.accountId,
                        signatory: self.multisigAccount.signatory,
                        chainId: self.chain.chainId,
                        multisigDefinition: .init(from: keyValue.value)
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
            operationManager: operationManager
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
            multisigAccountId: multisigAccount.accountId,
            signatoryAccountId: multisigAccount.signatory
        )
        let localFetchOperation = pendingOperationsRepository.fetchOperation(
            by: key.stringValue(),
            options: .init()
        )

        let updateOperation = ClosureOperation<Multisig.PendingOperation> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            return if let localPendingOperation = try? localFetchOperation.extractNoCancellableResultData() {
                localPendingOperation.replacingDefinition(with: multisigDefinition)
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
        }

        let saveOperation = pendingOperationsRepository.saveOperation(
            { [try updateOperation.extractNoCancellableResultData()] },
            { [] }
        )

        updateOperation.addDependency(localFetchOperation)
        saveOperation.addDependency(updateOperation)

        let operations = [localFetchOperation, updateOperation, saveOperation]

        operationManager.enqueue(
            operations: operations,
            in: .sync
        )
    }

    func removeOperation(with callHash: CallHash) {
        let key = Multisig.PendingOperation.Key(
            callHash: callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigAccount.accountId,
            signatoryAccountId: multisigAccount.signatory
        )
        let removeOperation = pendingOperationsRepository.saveOperation(
            { [] },
            { [key.stringValue()] }
        )

        operationManager.enqueue(
            operations: [removeOperation],
            in: .sync
        )
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

// MARK: - PendingMultisigLocalStorageSyncServiceProtocol

extension PendingMultisigLocalStorageSyncService: PendingMultisigLocalStorageSyncServiceProtocol {
    func syncPendingOperations(
        completionBlock: @escaping (_ updatedCallHashes: Set<CallHash>) -> Void
    ) {
        let remoteFetchWrapper = createPendingOperationsWrapper()
        remoteFetchWrapper.targetOperation.completionBlock = { [weak self] in
            guard let self else { return }

            do {
                let remotePendingOperations = try remoteFetchWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                let syncUpWrapper = createSyncUpWrapper(remotePendingOperations: remotePendingOperations)

                syncUpWrapper.targetOperation.completionBlock = {
                    do {
                        let updatedCallHashes = try syncUpWrapper
                            .targetOperation
                            .extractNoCancellableResultData()

                        completionBlock(updatedCallHashes)
                    } catch {
                        self.logger.error(
                            "Failed to sync pending operations: \(error), chainId: \(self.chain.chainId)"
                        )
                    }
                }

                operationManager.enqueue(
                    operations: syncUpWrapper.allOperations,
                    in: .sync
                )
            } catch {
                logger.error(
                    "Failed to fetch remote pending operations: \(error), chainId: \(chain.chainId)"
                )
            }
        }

        operationManager.enqueue(
            operations: remoteFetchWrapper.allOperations,
            in: .transient
        )
    }

    func updateDefinition(
        for callHash: CallHash,
        _ multisigDefinition: MultisigPallet.MultisigDefinition?
    ) {
        if let multisigDefinition {
            updateDefinition(
                for: callHash,
                multisigDefinition: .init(from: multisigDefinition)
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
