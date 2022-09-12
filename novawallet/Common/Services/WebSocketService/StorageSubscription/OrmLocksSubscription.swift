import RobinHood

final class OrmLocksSubscription: LocksSubscription {
    init(
        remoteStorageKey: Data,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetLock>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            storageCodingPath: .ormlTokenLocks,
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: repository,
            localModelsPredicate: { $0.accountId == accountId && $0.chainAssetId == chainAssetId },
            operationManager: operationManager,
            logger: logger
        )
    }
}

final class BalanceLocksSubscription: LocksSubscription {
    init(
        remoteStorageKey: Data,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetLock>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            storageCodingPath: .balanceLocks,
            remoteStorageKey: remoteStorageKey,
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: repository,
            localModelsPredicate: { $0.accountId == accountId },
            operationManager: operationManager,
            logger: logger
        )
    }
}

class LocksSubscription: StorageChildSubscribing {
    var remoteStorageKey: Data

    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetLock>
    let operationManager: OperationManagerProtocol
    let storageCodingPath: StorageCodingPath
    let localModelsPredicate: (AssetLock) -> Bool
    let logger: LoggerProtocol

    init(
        storageCodingPath: StorageCodingPath,
        remoteStorageKey: Data,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetLock>,
        localModelsPredicate: @escaping (AssetLock) -> Bool,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationManager = operationManager
        self.localModelsPredicate = localModelsPredicate
        self.storageCodingPath = storageCodingPath
        self.logger = logger
    }

    func processUpdate(_ data: Data?, blockHash _: Data?) {
        guard let data = data else {
            return
        }
        logger.debug("Did receive locks update")

        let decodingWrapper = createDecodingOperationWrapper(
            data: data,
            chainAssetId: chainAssetId
        )
        let changesWrapper = createChangesOperationWrapper(
            dependingOn: decodingWrapper,
            chainAssetId: chainAssetId,
            accountId: accountId
        )

        let saveOperation = createSaveOperation(dependingOn: changesWrapper)

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
            logger.error("Runtime metada unavailable for chain: \(chainAssetId.chainId)")
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable
            )
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<[BalanceLock]>(
            path: storageCodingPath,
            data: data
        )

        decodingOperation.configurationBlock = { [weak self] in
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                self?.logger.error("Error occur while decoding data: \(error.localizedDescription)")
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

        let changesOperation = ClosureOperation<[DataProviderChange<AssetLock>]?> { [weak self] in
            guard let localModelsPredicate = self?.localModelsPredicate else {
                self?.logger.debug("No locks received")
                return nil
            }

            let locks = try decodingWrapper.targetOperation.extractNoCancellableResultData() ?? []
            let localModels = try fetchOperation
                .extractNoCancellableResultData()
                .filter(localModelsPredicate)
                .sorted { $0.identifier < $1.identifier }

            var remoteModels = locks.map {
                AssetLock(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    type: $0.identifier,
                    amount: $0.amount
                )
            }.sorted { $0.identifier < $1.identifier }

            guard localModels != remoteModels else {
                self?.logger.debug("Local locks are actual")
                return nil
            }

            var changes: [DataProviderChange<AssetLock>] = []

            for localModel in localModels {
                if let remoteModelIndex = remoteModels.firstIndex(where: { $0.type == localModel.type }) {
                    let remoteModel = remoteModels[remoteModelIndex]
                    if localModel != remoteModel {
                        self?.logger.debug("Local lock: \(localModel) was updated. New amount: \(remoteModel.amount)")
                        changes.append(DataProviderChange.update(newItem: remoteModel))
                    }
                    remoteModels.remove(at: remoteModelIndex)
                } else {
                    self?.logger.debug("Lock: \(localModel) was removed")
                    changes.append(DataProviderChange.delete(deletedIdentifier: localModel.identifier))
                }
            }

            if !remoteModels.isEmpty {
                let newItems = remoteModels.map(DataProviderChange.update)
                self?.logger.debug("Locks: \(remoteModels) was added")
                changes.append(contentsOf: newItems)
            }

            return changes
        }

        changesOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: changesOperation, dependencies: [fetchOperation])
    }

    private func createSaveOperation(
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
