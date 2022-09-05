import RobinHood

final class OrmLocksSubscribtion: StorageChildSubscribing {
    var remoteStorageKey: Data

    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetLock>
    let operationManager: OperationManagerProtocol

    init(
        remoteStorageKey: Data,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetLock>,
        operationManager: OperationManagerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationManager = operationManager
    }

    func processUpdate(_ data: Data?, blockHash _: Data?) {
        guard let data = data else {
            return
        }
        let decodingWrapper = createDecodingOperationWrapper(
            data: data,
            chainAssetId: chainAssetId
        )
        let changesWrapper = createChangesOperationWrapper(
            dependingOn: decodingWrapper,
            chainAssetId: chainAssetId,
            accountId: accountId
        )

        let saveOperation = createSaveWrapper(dependingOn: changesWrapper)

        changesWrapper.addDependency(wrapper: decodingWrapper)
        saveOperation.addDependency(changesWrapper.targetOperation)

        let operations = decodingWrapper.allOperations + changesWrapper.allOperations + [saveOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func createDecodingOperationWrapper(
        data: Data,
        chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<[BalanceLock]?> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable
            )
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<[BalanceLock]>(
            path: .ormlTokenLocks,
            data: data
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    private func createChangesOperationWrapper(
        dependingOn decodingWrapper: CompoundOperationWrapper<[BalanceLock]?>,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> CompoundOperationWrapper<[DataProviderChange<AssetLock>]?> {
        let fetchOperation = repository.fetchAllOperation(with: .init())

        let changesOperation = ClosureOperation<[DataProviderChange<AssetLock>]?> {
            guard let locks = try decodingWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            let localModels = try fetchOperation.extractNoCancellableResultData()

            var remoteModels = locks.map {
                AssetLock(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    type: $0.identifier,
                    amount: $0.amount
                )
            }

            guard localModels != remoteModels else {
                return nil
            }

            var changes: [DataProviderChange<AssetLock>] = []

            for localModel in localModels {
                if let remoteModelIndex = remoteModels.firstIndex(where: { $0.type == localModel.type }) {
                    if localModel != remoteModels[remoteModelIndex] {
                        changes.append(DataProviderChange.update(newItem: remoteModels[remoteModelIndex]))
                    }
                    remoteModels.remove(at: remoteModelIndex)
                } else {
                    changes.append(DataProviderChange.delete(deletedIdentifier: localModel.identifier))
                }
            }

            let inserted = remoteModels.map {
                DataProviderChange.update(newItem: $0)
            }

            return changes + inserted
        }

        changesOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: changesOperation, dependencies: [fetchOperation])
    }

    private func createSaveWrapper(
        dependingOn operation: CompoundOperationWrapper<[DataProviderChange<AssetLock>]?>
    ) -> BaseOperation<Void> {
        let saveOperation = repository.saveOperation({
            guard let changes = try operation.targetOperation.extractNoCancellableResultData() else {
                return []
            }
            return changes.compactMap(\.item)
        }, {
            guard let changes = try operation.targetOperation.extractNoCancellableResultData() else {
                return []
            }

            return changes.compactMap { change in
                guard case let .delete(identifier) = change else {
                    return nil
                }
                return identifier
            }
        })

        saveOperation.addDependency(operation.targetOperation)
        return saveOperation
    }
}

import BigInt

struct AssetLock: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let type: Data
    let amount: BigUInt

    var lockType: LockType? {
        guard let typeString = type.toUTF8String() else {
            return nil
        }
        return LockType(rawValue: typeString)
    }
}

extension AssetLock: Identifiable {
    static func createIdentifier(
        for chainAssetId: ChainAssetId,
        accountId: AccountId,
        type: Data
    ) -> String {
        let data = [
            chainAssetId.stringValue,
            accountId.toHex(),
            type.toUTF8String()!
        ].joined(separator: "-").data(using: .utf8)!
        return data.sha256().toHex()
    }

    var identifier: String {
        Self.createIdentifier(for: chainAssetId, accountId: accountId, type: type)
    }
}
