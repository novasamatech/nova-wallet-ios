import Foundation
import Operation_iOS
import Foundation_iOS

struct NftDetailsViewFactory {
    static func createView(from model: NftChainModel) -> NftDetailsViewProtocol? {
        guard let interactor = createInteractor(from: model),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = NftDetailsWireframe()

        let localizationManager = LocalizationManager.shared

        let assetInfo = model.chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

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

    private static func createInteractor(
        from nftChainModel: NftChainModel
    ) -> (NftDetailsInteractor & NftDetailsInteractorInputProtocol)? {
        let mapper = MetaAccountMapper()
        let accountRepository = UserDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let nftMetadataService = NftFileDownloadService(
            cacheBasePath: ApplicationConfig.shared.fileCachePath,
            fileRepository: FileRepository(),
            fileDownloadFactory: FileDownloadOperationFactory(),
            operationQueue: OperationManagerFacade.fileDownloadQueue
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        switch NftType(rawValue: nftChainModel.nft.type) {
        case .rmrkV1:
            return createRMRKV1Interactor(
                from: nftChainModel,
                accountRepository: AnyDataProviderRepository(accountRepository),
                nftMetadataService: nftMetadataService,
                operationQueue: operationQueue
            )
        case .rmrkV2:
            return createRMRKV2Interactor(
                from: nftChainModel,
                accountRepository: AnyDataProviderRepository(accountRepository),
                nftMetadataService: nftMetadataService,
                operationQueue: operationQueue
            )
        case .uniques:
            return createUniquesInteractor(
                from: nftChainModel,
                accountRepository: AnyDataProviderRepository(accountRepository),
                nftMetadataService: nftMetadataService,
                operationQueue: operationQueue
            )
        case .pdc20:
            return createPdc20Interactor(
                from: nftChainModel,
                accountRepository: AnyDataProviderRepository(accountRepository),
                nftMetadataService: nftMetadataService,
                operationQueue: operationQueue
            )
        case .kodadot:
            return createKodaDotInteractor(
                from: nftChainModel,
                accountRepository: AnyDataProviderRepository(accountRepository),
                nftMetadataService: nftMetadataService,
                operationQueue: operationQueue
            )

        case .unique:
            return createUniqueInteractor(
                from: nftChainModel,
                accountRepository: AnyDataProviderRepository(accountRepository),
                nftMetadataService: nftMetadataService,
                operationQueue: operationQueue
            )
        case .none:
            return nil
        }
    }

    private static func createRMRKV1Interactor(
        from nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) -> RMRKV1DetailsInteractor? {
        RMRKV1DetailsInteractor(
            nftChainModel: nftChainModel,
            nftMetadataService: nftMetadataService,
            operationFactory: RMRKV1OperationFactory(),
            accountRepository: accountRepository,
            operationQueue: operationQueue
        )
    }

    private static func createRMRKV2Interactor(
        from nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) -> RMRKV2DetailsInteractor? {
        RMRKV2DetailsInteractor(
            nftChainModel: nftChainModel,
            nftMetadataService: nftMetadataService,
            operationFactory: RMRKV2OperationFactory(),
            accountRepository: accountRepository,
            operationQueue: operationQueue
        )
    }

    private static func createUniquesInteractor(
        from nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) -> UniquesDetailsInteractor? {
        UniquesDetailsInteractor(
            nftChainModel: nftChainModel,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationFactory: UniquesOperationFactory(),
            nftMetadataService: nftMetadataService,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: operationQueue
        )
    }

    private static func createPdc20Interactor(
        from nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) -> Pdc20DetailsInteractor? {
        Pdc20DetailsInteractor(
            nftChainModel: nftChainModel,
            accountRepository: accountRepository,
            nftMetadataService: nftMetadataService,
            operationQueue: operationQueue
        )
    }

    private static func createKodaDotInteractor(
        from nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) -> KodaDotDetailsInteractor? {
        guard
            nftChainModel.nft.type == NftType.kodadot.rawValue,
            let apiUrl = KodaDotAssetHubApi.apiForChain(nftChainModel.chainAsset.chain.chainId) else {
            return nil
        }

        return KodaDotDetailsInteractor(
            nftChainModel: nftChainModel,
            nftMetadataService: nftMetadataService,
            operationFactory: KodaDotNftOperationFactory(url: apiUrl),
            accountRepository: accountRepository,
            operationQueue: operationQueue
        )
    }

    private static func createUniqueInteractor(
        from nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        nftMetadataService: NftFileDownloadServiceProtocol,
        operationQueue: OperationQueue
    ) -> (NftDetailsInteractor & NftDetailsInteractorInputProtocol)? {
        UniqueDetailsInteractor(
            nftChainModel: nftChainModel,
            nftMetadataService: nftMetadataService,
            operationFactory: UniqueNftOperationFactory(apiBase: UniqueScanApi.mainnet),
            accountRepository: accountRepository,
            operationQueue: operationQueue
        )
    }
}
