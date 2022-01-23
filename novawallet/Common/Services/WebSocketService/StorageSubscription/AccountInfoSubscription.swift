import Foundation
import RobinHood

final class AccountInfoSubscription: BaseStorageChildSubscription {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let assetRepository: AnyDataProviderRepository<AssetBalance>
    let transactionSubscription: TransactionSubscription
    let eventCenter: EventCenterProtocol

    init(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        assetRepository: AnyDataProviderRepository<AssetBalance>,
        transactionSubscription: TransactionSubscription,
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
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

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    override func handle(
        result: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem: ChainStorageItem?,
        blockHash: Data?
    ) {
        logger.debug("Did account info update")

        decodeAndSaveAccountInfo(remoteItem, chainAssetId: chainAssetId, accountId: accountId)

        if case let .success(optionalChange) = result, let change = optionalChange {
            logger.debug("Did change account info")

            if let blockHash = blockHash {
                transactionSubscription.process(blockHash: blockHash)
            }

            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }
    }

    private func decodeAndSaveAccountInfo(
        _ item: ChainStorageItem?,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let decodingOperation = StorageFallbackDecodingOperation<AccountInfo>(
            path: .account,
            data: item?.data
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let identifier = AssetBalance.createIdentifier(for: chainAssetId, accountId: accountId)
        let fetchOperation = assetRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let saveOperation = assetRepository.saveOperation({
            let accountInfo = try decodingOperation.extractNoCancellableResultData()
            let localModel = try fetchOperation.extractNoCancellableResultData()

            let remoteModel = AssetBalance(
                chainAssetId: chainAssetId,
                accountId: accountId,
                freeInPlank: accountInfo?.data.free ?? 0,
                reservedInPlank: accountInfo?.data.reserved ?? 0,
                frozenInPlank: accountInfo?.data.locked ?? 0
            )

            if localModel != remoteModel, remoteModel.totalInPlank > 0 {
                return [remoteModel]
            } else {
                return []
            }
        }, {
            let accountInfo = try decodingOperation.extractNoCancellableResultData()
            let localModel = try fetchOperation.extractNoCancellableResultData()

            let total = accountInfo?.data.total ?? 0

            if total == 0, localModel != nil {
                return [identifier]
            } else {
                return []
            }
        })

        saveOperation.addDependency(fetchOperation)
        saveOperation.addDependency(decodingOperation)

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation, fetchOperation, saveOperation],
            in: .transient
        )
    }
}
