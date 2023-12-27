import Foundation
import SoraFoundation
import SoraKeystore

struct AssetListViewFactory {
    static func createView(
        with dappMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol
    ) -> AssetListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared,
              let walletConnect = dappMediator.children.first(
                  where: { $0 is WalletConnectDelegateInputProtocol }
              ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        let assetListModelObservable = AssetListModelObservable(state: .init(value: .init()))

        let interactor = AssetListInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetListModelObservable: assetListModelObservable,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            walletNotificationService: walletNotificationService,
            nftLocalSubscriptionFactory: NftLocalSubscriptionFactory.shared,
            externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared,
            settingsManager: SettingsManager.shared,
            currencyManager: currencyManager,
            walletConnect: walletConnect,
            logger: Logger.shared
        )

        let wireframe = AssetListWireframe(
            dappMediator: dappMediator,
            assetListModelObservable: assetListModelObservable
        )

        let nftDownloadService = NftFileDownloadService(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: FileRepository(),
            fileDownloadFactory: FileDownloadOperationFactory(),
            operationQueue: OperationManagerFacade.fileDownloadQueue
        )

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            nftDownloadService: nftDownloadService,
            currencyManager: currencyManager
        )
        let localizationManager = LocalizationManager.shared

        let presenter = AssetListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = AssetListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
