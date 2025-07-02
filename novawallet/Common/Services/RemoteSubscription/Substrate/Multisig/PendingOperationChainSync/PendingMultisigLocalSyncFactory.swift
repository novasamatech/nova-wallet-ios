import Foundation
import SubstrateSdk
import Operation_iOS

typealias MultisigPendingOperationsMap = [Multisig.PendingOperation.Key: Multisig.PendingOperation]

protocol PendingMultisigLocalSyncFactoryProtocol {
    func createSyncLocalWrapper(
        with remotePendingOperations: MultisigPendingOperationsMap
    ) -> CompoundOperationWrapper<Set<Substrate.CallHash>>

    func createUpdateDefinitionWrapper(
        for callHash: Substrate.CallHash,
        _ multisigDefinition: MultisigDefinitionWithTime?
    ) -> CompoundOperationWrapper<Void>

    func createFetchLocalHashesWrapper() -> CompoundOperationWrapper<Set<Substrate.CallHash>>
}

final class PendingMultisigLocalSyncFactory {
    private let multisigAccount: DelegatedAccount.MultisigAccountModel
    private let chain: ChainModel
    private let pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>
    private let logger: LoggerProtocol

    init(
        multisigAccount: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel,
        pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.multisigAccount = multisigAccount
        self.chain = chain
        self.pendingOperationsRepository = pendingOperationsRepository
        self.logger = logger
    }
}

// MARK: - Private

private extension PendingMultisigLocalSyncFactory {
    func createCallHashDiffOperation(
        remotePendingOperations: MultisigPendingOperationsMap,
        dependsOn localFetchOperation: BaseOperation<[Multisig.PendingOperation]>
    ) -> ClosureOperation<OperationsChanges> {
        ClosureOperation<OperationsChanges> {
            let oldCallKeys = try localFetchOperation
                .extractNoCancellableResultData()
                .map { $0.createKey() }

            let allKeys = remotePendingOperations.map(\.key)

            let allKeysSet = Set(allKeys)
            let oldKeySet = Set(oldCallKeys)

            return OperationsChanges(
                newOperations: allKeysSet.subtracting(oldKeySet),
                updatedOperations: allKeysSet.intersection(oldKeySet),
                removedOperationsKeys: oldKeySet.subtracting(allKeysSet)
            )
        }
    }

    func createUpdateOperation(
        remotePendingOperations: MultisigPendingOperationsMap,
        dependsOn localFetchOperation: BaseOperation<[Multisig.PendingOperation]>,
        _ changesOperation: BaseOperation<OperationsChanges>
    ) -> BaseOperation<Void> {
        pendingOperationsRepository.saveOperation({
            let changes = try changesOperation.extractNoCancellableResultData()

            let localPendingOperations = try localFetchOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0[$1.createKey()] = $1 }

            let newItems = changes.newOperations.compactMap { remotePendingOperations[$0] }
            let updates: [Multisig.PendingOperation] = changes.updatedOperations.compactMap { key in
                guard let remote = remotePendingOperations[key] else { return nil }

                return localPendingOperations[key]?.updating(with: remote)
            }

            return newItems + updates
        }, {
            try changesOperation
                .extractNoCancellableResultData()
                .removedOperationsKeys
                .map { $0.stringValue() }
        })
    }

    func updateDefinition(
        for callHash: Substrate.CallHash,
        multisigDefinition: MultisigDefinitionWithTime
    ) -> CompoundOperationWrapper<Void> {
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

            let localDefinition = Multisig.MultisigDefinition(
                from: multisigDefinition.definition
            )

            return if let localPendingOperation = try? localFetchOperation.extractNoCancellableResultData() {
                localPendingOperation.replacingDefinition(with: localDefinition)
            } else {
                Multisig.PendingOperation(
                    call: nil,
                    callHash: callHash,
                    timestamp: multisigDefinition.timestamp,
                    multisigAccountId: multisigAccount.accountId,
                    signatory: multisigAccount.signatory,
                    chainId: self.chain.chainId,
                    multisigDefinition: localDefinition
                )
            }
        }
        let saveOperation = pendingOperationsRepository.saveOperation({
            [try updateOperation.extractNoCancellableResultData()]
        }, {
            []
        })

        updateOperation.addDependency(localFetchOperation)
        saveOperation.addDependency(updateOperation)

        return CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [localFetchOperation, updateOperation]
        )
    }

    func removeOperation(with callHash: Substrate.CallHash) -> BaseOperation<Void> {
        let key = Multisig.PendingOperation.Key(
            callHash: callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigAccount.accountId,
            signatoryAccountId: multisigAccount.signatory
        )

        return pendingOperationsRepository.saveOperation({
            []
        }, {
            [key.stringValue()]
        })
    }
}

// MARK: - PendingMultisigLocalSyncFactoryProtocol

extension PendingMultisigLocalSyncFactory: PendingMultisigLocalSyncFactoryProtocol {
    func createSyncLocalWrapper(
        with remotePendingOperations: MultisigPendingOperationsMap
    ) -> CompoundOperationWrapper<Set<Substrate.CallHash>> {
        let localFetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())
        let diffOperation = createCallHashDiffOperation(
            remotePendingOperations: remotePendingOperations,
            dependsOn: localFetchOperation
        )
        let updateOperation = createUpdateOperation(
            remotePendingOperations: remotePendingOperations,
            dependsOn: localFetchOperation,
            diffOperation
        )
        let resultOperation = ClosureOperation<Set<Substrate.CallHash>> {
            let changes = try diffOperation.extractNoCancellableResultData()

            let allHashes = changes.newOperations
                .union(changes.updatedOperations)
                .map(\.callHash)

            return Set(allHashes)
        }

        diffOperation.addDependency(localFetchOperation)
        updateOperation.addDependency(diffOperation)
        resultOperation.addDependency(updateOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [localFetchOperation, diffOperation, updateOperation]
        )
    }

    func createUpdateDefinitionWrapper(
        for callHash: Substrate.CallHash,
        _ multisigDefinition: MultisigDefinitionWithTime?
    ) -> CompoundOperationWrapper<Void> {
        if let multisigDefinition {
            updateDefinition(for: callHash, multisigDefinition: multisigDefinition)
        } else {
            CompoundOperationWrapper(targetOperation: removeOperation(with: callHash))
        }
    }

    func createFetchLocalHashesWrapper() -> CompoundOperationWrapper<Set<Substrate.CallHash>> {
        let fetchOperation = pendingOperationsRepository.fetchAllOperation(with: .init())

        let mapOperation = ClosureOperation<Set<Substrate.CallHash>> {
            Set(
                try fetchOperation
                    .extractNoCancellableResultData()
                    .map(\.callHash)
            )
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }
}

// MARK: - Local types

private struct OperationsChanges {
    let newOperations: Set<Multisig.PendingOperation.Key>
    let updatedOperations: Set<Multisig.PendingOperation.Key>
    let removedOperationsKeys: Set<Multisig.PendingOperation.Key>
}
