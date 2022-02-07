import Foundation
import RobinHood

final class EmptyHandlingStorageSubscription: BaseStorageChildSubscription {
    override func handle(
        result _: Result<DataProviderChange<ChainStorageItem>?, Error>,
        remoteItem _: ChainStorageItem?,
        blockHash _: Data?
    ) {
        logger.debug("Did handle update for key: \(remoteStorageKey.toHex(includePrefix: true))")
    }
}
