import Foundation
import RobinHood
import SoraFoundation

struct NftDetailsViewFactory {
    static func createView(from model: NftChainModel) -> NftDetailsViewProtocol? {
        let mapper = MetaAccountMapper()
        let accountRepository = UserDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let nftDownloadService = NftFileDownloadService(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: FileRepository(),
            fileDownloadFactory: FileDownloadOperationFactory(),
            operationQueue: OperationManagerFacade.fileDownloadQueue
        )

        let interactor = UniquesDetailsInteractor(
            nftChainModel: model,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationFactory: UniquesOperationFactory(),
            metadataService: nftDownloadService,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = NftDetailsWireframe()

        let localizationManager = LocalizationManager.shared

        let assetInfo = model.chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let quantityFormatter = NumberFormatter.quantity.localizableResource()

        let presenter = NftDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            quantityFactory: quantityFormatter,
            chainAsset: model.chainAsset,
            localizationManager: localizationManager
        )

        let view = NftDetailsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
