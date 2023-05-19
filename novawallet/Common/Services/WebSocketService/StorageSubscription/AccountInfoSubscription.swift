import Foundation
import RobinHood

final class AccountInfoSubscription {
    let remoteStorageKey: Data
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let transactionSubscription: TransactionSubscription?
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol
    let operationManager: OperationManagerProtocol

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        transactionSubscription: TransactionSubscription?,
        remoteStorageKey: Data,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.assetRepository = assetRepository
        self.transactionSubscription = transactionSubscription
        self.eventCenter = eventCenter
        self.remoteStorageKey = remoteStorageKey
        self.operationManager = operationManager
        self.logger = logger
    }

    private func createDecodingOperationWrapper(
        _ item: Data?,
        chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AccountInfo?> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable
            )
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<AccountInfo>(
            path: .account,
            data: item
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    private func createChangesOperationWrapper(
        dependingOn decodingWrapper: CompoundOperationWrapper<AccountInfo?>,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> CompoundOperationWrapper<DataProviderChange<AssetBalance>?> {
        let identifier = AssetBalance.createIdentifier(for: chainAssetId, accountId: accountId)
        let fetchOperation = assetRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let changesOperation = ClosureOperation<DataProviderChange<AssetBalance>?> {
            let account = try decodingWrapper.targetOperation.extractNoCancellableResultData()
            let localModel = try fetchOperation.extractNoCancellableResultData()

            let remoteModel = AssetBalance(
                chainAssetId: chainAssetId,
                accountId: accountId,
                freeInPlank: account?.data.free ?? 0,
                reservedInPlank: account?.data.reserved ?? 0,
                frozenInPlank: account?.data.locked ?? 0,
                blocked: false
            )

            if localModel != remoteModel, remoteModel.totalInPlank > 0 {
                return DataProviderChange.update(newItem: remoteModel)
            } else if localModel != nil, remoteModel.totalInPlank == 0 {
                return DataProviderChange.delete(deletedIdentifier: identifier)
            } else {
                return nil
            }
        }

        changesOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: changesOperation, dependencies: [fetchOperation])
    }

    private func decodeAndSaveAccountInfo(
        _ item: Data?,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        blockHash: Data?
    ) {
        let decodingWrapper = createDecodingOperationWrapper(
            item,
            chainAssetId: chainAssetId
        )

        let changesWrapper = createChangesOperationWrapper(
            dependingOn: decodingWrapper,
            chainAssetId: chainAssetId,
            accountId: accountId
        )

        let saveOperation = assetRepository.saveOperation({
            let change = try changesWrapper.targetOperation.extractNoCancellableResultData()

            if let remoteModel = change?.item {
                return [remoteModel]
            } else {
                return []
            }
        }, {
            let change = try changesWrapper.targetOperation.extractNoCancellableResultData()

            if case let .delete(identifier) = change {
                return [identifier]
            } else {
                return []
            }
        })

        changesWrapper.addDependency(wrapper: decodingWrapper)
        saveOperation.addDependency(changesWrapper.targetOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.global().async {
                let maybeItem = try? changesWrapper.targetOperation.extractNoCancellableResultData()

                if maybeItem != nil {
                    self?.handleTransactionIfNeeded(for: blockHash)

                    let assetBalanceChangeEvent = AssetBalanceChanged(
                        chainAssetId: chainAssetId,
                        accountId: accountId,
                        changes: item,
                        block: blockHash
                    )

                    self?.eventCenter.notify(with: assetBalanceChangeEvent)
                }
            }
        }

        let operations = decodingWrapper.allOperations + changesWrapper.allOperations + [saveOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func handleTransactionIfNeeded(for blockHash: Data?) {
        if let blockHash = blockHash {
            logger.debug("Handle account info transaction")
            transactionSubscription?.process(blockHash: blockHash)
        }
    }
}

extension AccountInfoSubscription: StorageChildSubscribing {
    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did account info update")

        decodeAndSaveAccountInfo(
            data,
            chainAssetId: chainAssetId,
            accountId: accountId,
            blockHash: blockHash
        )
    }
}
