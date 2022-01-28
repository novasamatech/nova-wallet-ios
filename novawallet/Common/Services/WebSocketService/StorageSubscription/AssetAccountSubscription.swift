import RobinHood

class BaseAssetAccountSubscription: BaseStorageChildSubscription {
    let assetBalanceUpdater: AssetsBalanceUpdater

    init(
        assetBalanceUpdater: AssetsBalanceUpdater,
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.assetBalanceUpdater = assetBalanceUpdater

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    func handle(storageItem _: ChainStorageItem?) {
        fatalError("Must be overriden by subclass")
    }

    override func handle(
        result: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem: ChainStorageItem?,
        blockHash _: Data?
    ) {
        logger.debug("Did receive asset account update")

        if case .success = result {
            logger.debug("Successfull asset account info")

            handle(storageItem: remoteItem)
        }
    }
}

final class AssetAccountSubscription: BaseAssetAccountSubscription {
    override func handle(storageItem: ChainStorageItem?) {
        assetBalanceUpdater.handleAssetAccount(value: storageItem)
    }
}

final class AssetDetailsSubscription: BaseAssetAccountSubscription {
    override func handle(storageItem: ChainStorageItem?) {
        assetBalanceUpdater.handleAssetDetails(value: storageItem)
    }
}
