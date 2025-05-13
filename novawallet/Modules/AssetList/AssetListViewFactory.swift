import Foundation
import Foundation_iOS
import Keystore_iOS

struct AssetListViewFactory {
    static func createView() -> ScrollViewHostControlling? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let assetListModelObservable = AssetListModelObservable(state: .init(value: .init()))

        let interactor = AssetListInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetListModelObservable: assetListModelObservable,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            nftLocalSubscriptionFactory: NftLocalSubscriptionFactory.shared,
            externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared,
            settingsManager: SettingsManager.shared,
            currencyManager: currencyManager,
            logger: Logger.shared
        )

        let wireframe = AssetListWireframe(assetListModelObservable: assetListModelObservable)

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
            chainAssetViewModelFactory: ChainAssetViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            nftDownloadService: nftDownloadService,
            currencyManager: currencyManager
        )
        let localizationManager = LocalizationManager.shared
        let appearanceFacade = AppearanceFacade.shared

        let presenter = AssetListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            appearanceFacade: appearanceFacade
        )

        guard let bannerModule = BannersViewFactory.createView(
            domain: .assets,
            output: presenter,
            inputOwner: presenter,
            locale: localizationManager.selectedLocale
        ) else { return nil }

        let view = AssetListViewController(
            presenter: presenter,
            bannersViewProvider: bannerModule,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
