import Operation_iOS

protocol EquillibriumLocksUpdaterProtocol {
    func handle(value: Data?, blockHash: Data?)
}

final class EquillibriumLocksUpdater: EquillibriumLocksUpdaterProtocol {
    let logger: LoggerProtocol
    let chainAssetId: ChainAssetId
    let repository: AnyDataProviderRepository<AssetLock>
    let chainRegistry: ChainRegistryProtocol
    let accountId: AccountId
    let queue: OperationQueue

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        repository: AnyDataProviderRepository<AssetLock>,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol,
        queue: OperationQueue
    ) {
        self.logger = logger
        self.chainAssetId = chainAssetId
        self.repository = repository
        self.chainRegistry = chainRegistry
        self.accountId = accountId
        self.queue = queue
    }

    func handle(value: Data?, blockHash _: Data?) {
        logger.debug("Did receive locks update")

        let decodingWrapper: CompoundOperationWrapper<[EquilibriumLock]?> =
            CommonOperationWrapper.storageDecoderWrapper(
                for: value,
                path: .equilibriumLocks,
                chainModelId: chainAssetId.chainId,
                chainRegistry: chainRegistry
            )

        let saveOperation = createSaveOperation(
            dependingOn: decodingWrapper.targetOperation
        )

        saveOperation.addDependency(decodingWrapper.targetOperation)

        let operations = decodingWrapper.allOperations + [saveOperation]

        queue.addOperations(operations, waitUntilFinished: false)
    }

    private func createSaveOperation(
        dependingOn decodingOperation: BaseOperation<[EquilibriumLock]?>
    ) -> BaseOperation<Void> {
        let replaceOperation = repository.replaceOperation {
            let remoteItems = try decodingOperation.extractNoCancellableResultData() ?? []

            return remoteItems.compactMap { remoteItem in
                AssetLock(
                    chainAssetId: self.chainAssetId,
                    accountId: self.accountId,
                    type: remoteItem.type,
                    amount: remoteItem.amount,
                    storage: AssetLockStorage.locks.rawValue,
                    module: nil
                )
            }
        }

        return replaceOperation
    }
}
