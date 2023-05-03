import Foundation
import RobinHood

final class DAppStateDataSource {
    let chainsStore: ChainsStoreProtocol
    let dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue
    let walletSettings: SelectedWalletSettings

    init(
        chainsStore: ChainsStoreProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        walletSettings: SelectedWalletSettings,
        operationQueue: OperationQueue
    ) {
        self.chainsStore = chainsStore
        self.dAppSettingsRepository = dAppSettingsRepository
        self.walletsRepository = walletsRepository
        self.walletSettings = walletSettings
        self.operationQueue = operationQueue
    }
}
