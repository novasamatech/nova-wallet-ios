import Foundation
import Operation_iOS

class BaseAssetAccountSubscription {
    let remoteStorageKey: Data
    let assetBalanceUpdater: AssetsBalanceUpdater
    let logger: LoggerProtocol

    init(
        assetBalanceUpdater: AssetsBalanceUpdater,
        remoteStorageKey: Data,
        logger: LoggerProtocol
    ) {
        self.assetBalanceUpdater = assetBalanceUpdater
        self.remoteStorageKey = remoteStorageKey
        self.logger = logger
    }
}

final class AssetAccountSubscription: BaseAssetAccountSubscription, StorageChildSubscribing {
    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset account update")

        assetBalanceUpdater.handleAssetAccount(value: data, blockHash: blockHash)
    }
}

final class AssetDetailsSubscription: BaseAssetAccountSubscription, StorageChildSubscribing {
    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did receive asset details update")

        assetBalanceUpdater.handleAssetDetails(value: data, blockHash: blockHash)
    }
}
