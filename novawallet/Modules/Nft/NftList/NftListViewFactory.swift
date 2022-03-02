import Foundation
import SoraFoundation

struct NftListViewFactory {
    static func createView() -> NftListViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = NftListWireframe()

        let nftDownloadService = NftFileDownloadService(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: FileRepository(),
            fileDownloadFactory: FileDownloadOperationFactory(),
            operationQueue: OperationManagerFacade.fileDownloadQueue
        )

        let quantityFormatter = NumberFormatter.quantity.localizableResource()

        let viewModelFactory = NftListViewModelFactory(
            nftDownloadService: nftDownloadService,
            quantityFormatter: quantityFormatter
        )

        let localizationManager = LocalizationManager.shared

        let presenter = NftListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            locale: localizationManager.selectedLocale
        )

        let view = NftListViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            quantityFormatter: quantityFormatter
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> NftListInteractor? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        return NftListInteractor(
            wallet: wallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            nftLocalSubscriptionFactory: NftLocalSubscriptionFactory.shared
        )
    }
}
