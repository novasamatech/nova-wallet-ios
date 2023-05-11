import Foundation
import RobinHood
import SoraFoundation

struct WalletConnectServiceFactory {
    static func createInteractor(
        chainsStore: ChainsStoreProtocol,
        settingsRepository: AnyDataProviderRepository<DAppSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) -> WalletConnectInteractor {
        let metadata = WalletConnectMetadata.nova(with: WalletConnectSecret.getProjectId())
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

        let presenter = WalletConnectPresenter(
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )

        return .init(
            transport: transport,
            presenter: presenter,
            securedLayer: SecurityLayerService.shared
        )
    }
}
