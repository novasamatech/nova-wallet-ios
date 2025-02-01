import Foundation
import Operation_iOS

class HoldsSubscription: StorageChildSubscribing {
    var remoteStorageKey: Data

    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<AssetHold>
    let operationManager: OperationManagerProtocol
    let storageCodingPath: StorageCodingPath
    let logger: LoggerProtocol

    init(
        storageCodingPath: StorageCodingPath,
        remoteStorageKey: Data,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<AssetHold>,
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
        logger.debug("Did receive holds update")

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
    ) -> CompoundOperationWrapper<[BalancesPallet.Hold]?> {
        guard let data = data else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            logger.error("Runtime metadata unavailable for chain: \(chainAssetId.chainId)")
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable(chainAssetId.chainId)
            )
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<[BalancesPallet.Hold]>(
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

    private func createSaveOperation(
        dependingOn decodingOperation: BaseOperation<[BalancesPallet.Hold]?>,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        logger: LoggerProtocol
    ) -> BaseOperation<Void> {
        let replaceOperation = repository.replaceOperation {
            let remoteItems = try decodingOperation.extractNoCancellableResultData() ?? []

            logger.debug("Saving holds: \(remoteItems)")

            return remoteItems.map { remoteItem in
                AssetHold(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    module: remoteItem.holdId.module,
                    reason: remoteItem.holdId.reason,
                    amount: remoteItem.amount
                )
            }
        }

        return replaceOperation
    }
}
