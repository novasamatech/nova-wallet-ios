import Foundation
import RobinHood

final class DAppStateDataSource {
    let chainsStore: ChainsStoreProtocol
    let dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>
    let operationQueue: OperationQueue
    let walletSettings: SelectedWalletSettings

    init(
        chainsStore: ChainsStoreProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        walletSettings: SelectedWalletSettings,
        operationQueue: OperationQueue
    ) {
        self.chainsStore = chainsStore
        self.dAppSettingsRepository = dAppSettingsRepository
        self.walletSettings = walletSettings
        self.operationQueue = operationQueue
    }
}
