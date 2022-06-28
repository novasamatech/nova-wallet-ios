import RobinHood

class BaseAssetAccountSubscription: BaseStorageChildSubscription {
    let assetBalanceUpdater: AssetsBalanceUpdater
    let transactionSubscription: TransactionSubscription?

    init(
        assetBalanceUpdater: AssetsBalanceUpdater,
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        transactionSubscription: TransactionSubscription?,
        logger: LoggerProtocol
    ) {
        self.assetBalanceUpdater = assetBalanceUpdater
        self.transactionSubscription = transactionSubscription

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    func handle(storageItem _: ChainStorageItem?, isRemoved _: Bool) {
        fatalError("Must be overriden by subclass")
    }

    override func handle(
        result: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem: ChainStorageItem?,
        blockHash: Data?
    ) {
        logger.debug("Did receive asset account update")

        if case let .success(optionalChange) = result {
            logger.debug("Successfull asset account info")

            let isRemoved = optionalChange?.isDeletion ?? false

            handle(storageItem: remoteItem, isRemoved: isRemoved)

            if optionalChange != nil, let blockHash = blockHash {
                transactionSubscription?.process(blockHash: blockHash)
            }
        }
    }
}

final class AssetAccountSubscription: BaseAssetAccountSubscription {
    override func handle(storageItem: ChainStorageItem?, isRemoved: Bool) {
        assetBalanceUpdater.handleAssetAccount(value: storageItem, isRemoved: isRemoved)
    }
}

final class AssetDetailsSubscription: BaseAssetAccountSubscription {
    override func handle(storageItem: ChainStorageItem?, isRemoved: Bool) {
        assetBalanceUpdater.handleAssetDetails(value: storageItem, isRemoved: isRemoved)
    }
}
