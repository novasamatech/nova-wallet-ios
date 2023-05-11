import Foundation
import RobinHood

struct WalletConnectServiceFactory {
    static func createInteractor(
        chainsStore: ChainsStoreProtocol,
        settingsRepository: AnyDataProviderRepository<DAppSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) -> WalletConnectInteractor {
        let metadata = WalletConnectMetadata.nova(with: ApplicationConfig.shared.walletConnectProjectId)
        let service = WalletConnectService(metadata: metadata)

        let dataSource = DAppStateDataSource(
            chainsStore: chainsStore,
            dAppSettingsRepository: settingsRepository,
            walletsRepository: walletsRepository,
            walletSettings: SelectedWalletSettings.shared,
            operationQueue: operationQueue
        )

        let transport = WalletConnectTransport(
            service: service,
            dataSource: dataSource,
            logger: Logger.shared
        )

        return .init(
            transport: transport,
            presenter: WalletConnectPresenter(logger: Logger.shared)
        )
    }
}
