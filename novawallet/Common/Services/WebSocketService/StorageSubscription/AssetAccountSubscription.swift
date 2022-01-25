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

    func handle(change _: DataProviderChange<ChainStorageItem>?) {
        fatalError("Must be overriden by subclass")
    }

    override func handle(
        result: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem _: ChainStorageItem?,
        blockHash _: Data?
    ) {
        logger.debug("Did receive asset account update")

        if case let .success(optionalChange) = result {
            logger.debug("Successfull asset account info")

            handle(change: optionalChange)
        }
    }
}

final class AssetAccountSubscription: BaseAssetAccountSubscription {
    override func handle(change: DataProviderChange<ChainStorageItem>?) {
        assetBalanceUpdater.handleAssetAccount(change: change, localKey: localStorageKey)
    }
}

final class AssetDetailsSubscription: BaseAssetAccountSubscription {
    override func handle(change: DataProviderChange<ChainStorageItem>?) {
        assetBalanceUpdater.handleAssetDetails(change: change, localKey: localStorageKey)
    }
}
