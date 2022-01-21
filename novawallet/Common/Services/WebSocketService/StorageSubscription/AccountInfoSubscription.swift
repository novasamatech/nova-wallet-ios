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

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.debug("Did account info update")

        if case let .success(optionalChange) = result, let change = optionalChange {
            logger.debug("Did change account info")

            switch change {
            case let .insert(newItem), let .update(newItem):
                decodeAndSaveAccountInfo(newItem, chainAssetId: chainAssetId, accountId: accountId)
            case .delete:
                decodeAndSaveAccountInfo(nil, chainAssetId: chainAssetId, accountId: accountId)
            }

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

        let saveOperation = assetRepository.saveOperation({
            let accountInfo = try decodingOperation.extractNoCancellableResultData()

            let total = accountInfo?.data.total ?? 0

            if total > 0 {
                let assetBalance = AssetBalance(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    freeInPlank: accountInfo?.data.free ?? 0,
                    reservedInPlank: accountInfo?.data.reserved ?? 0,
                    frozenInPlank: accountInfo?.data.frozen ?? 0
                )

                return [assetBalance]
            } else {
                return []
            }
        }, {
            let accountInfo = try decodingOperation.extractNoCancellableResultData()

            let total = accountInfo?.data.total ?? 0

            if total == 0 {
                return [identifier]
            } else {
                return []
            }
        })

        saveOperation.addDependency(decodingOperation)

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation, saveOperation],
            in: .transient
        )
    }
}
