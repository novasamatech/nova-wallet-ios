import Foundation
import SoraFoundation
import SoraKeystore

struct WalletListViewFactory {
    static func createView() -> WalletListViewProtocol? {
        let interactor = WalletListInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            nftLocalSubscriptionFactory: NftLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared,
            settingsManager: SettingsManager.shared
        )

        let wireframe = WalletListWireframe(walletUpdater: WalletDetailsUpdater.shared)

        let nftDownloadService = NftFileDownloadService(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: FileRepository(),
            fileDownloadFactory: FileDownloadOperationFactory(),
            operationQueue: OperationManagerFacade.fileDownloadQueue
        )

        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.usd())
        let viewModelFactory = WalletListViewModelFactory(
            priceFormatter: priceFormatter,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            nftDownloadService: nftDownloadService
        )
        let localizationManager = LocalizationManager.shared

        let presenter = WalletListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = WalletListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
