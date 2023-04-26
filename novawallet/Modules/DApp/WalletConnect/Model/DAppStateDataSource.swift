import Foundation
import RobinHood

final class DAppStateDataSource {
    let chainsStore: ChainsStoreProtocol
    let dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>
    let operationQueue: OperationQueue

    init(
        chainsStore: ChainsStoreProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        operationQueue: OperationQueue
    ) {
        self.chainsStore = chainsStore
        self.dAppSettingsRepository = dAppSettingsRepository
        self.operationQueue = operationQueue
    }
}
