import Foundation
import Operation_iOS

class FreezesSubscription: StorageChildSubscribing {
    var remoteStorageKey: Data

    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetLock>
    let operationManager: OperationManagerProtocol
    let storageCodingPath: StorageCodingPath
    let logger: LoggerProtocol

    init(
        storageCodingPath: StorageCodingPath,
        remoteStorageKey: Data,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetLock>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationManager = operationManager
        self.storageCodingPath = storageCodingPath
        self.logger = logger
    }

    func processUpdate(_ data: Data?, blockHash _: Data?) {
        logger.debug("Did receive freezes update")

        let decodingWrapper = createDecodingOperationWrapper(
            data: data,
            chainAssetId: chainAssetId
        )

        let saveOperation = createSaveOperation(
            dependingOn: decodingWrapper.targetOperation,
            chainAssetId: chainAssetId,
            accountId: accountId,
            logger: logger
        )

        saveOperation.addDependency(decodingWrapper.targetOperation)

        let operations = decodingWrapper.allOperations + [saveOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func createDecodingOperationWrapper(
        data: Data?,
        chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<[BalancesPallet.Freeze]?> {
        guard let data = data else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            logger.error("Runtime metadata unavailable for chain: \(chainAssetId.chainId)")
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable
            )
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<[BalancesPallet.Freeze]>(
            path: storageCodingPath,
            data: data
        )

        decodingOperation.configurationBlock = { [weak self] in
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                self?.logger.error("Error occured while decoding data: \(error.localizedDescription)")
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    private func createSaveOperation(
        dependingOn decodingOperation: BaseOperation<[BalancesPallet.Freeze]?>,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        logger: LoggerProtocol
    ) -> BaseOperation<Void> {
        let replaceOperation = repository.replaceOperation {
            let remoteItems = try decodingOperation.extractNoCancellableResultData() ?? []

            logger.debug("Saving freeze: \(remoteItems)")

            return remoteItems.map { remoteItem in
                let type = remoteItem.freezeId.reason.data(using: .utf8) ?? Data()

                return AssetLock(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    type: type,
                    amount: remoteItem.amount,
                    storage: AssetLockStorage.freezes.rawValue,
                    module: remoteItem.freezeId.module
                )
            }
        }

        return replaceOperation
    }
}
