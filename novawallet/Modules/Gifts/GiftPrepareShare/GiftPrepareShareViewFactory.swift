import Foundation
import Foundation_iOS
import Operation_iOS
import Keystore_iOS

struct GiftPrepareShareViewFactory {
    static func createView(
        giftId: GiftModel.Id,
        chainAsset: ChainAsset,
        style: GiftPrepareShareViewStyle
    ) -> GiftPrepareShareViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let storageFacade = UserDataStorageFacade.shared
        let repositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let giftRepository = repositoryFactory.createGiftsRepository(for: nil)

        let giftSecretsManager = GiftSecretsManager(keystore: Keychain())

        let interactor = GiftPrepareShareInteractor(
            giftRepository: giftRepository,
            giftSecretsManager: giftSecretsManager,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            giftId: giftId,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
        let wireframe = GiftPrepareShareWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let universalLinkFactory = ExternalLinkFactory(
            baseUrl: ApplicationConfig.shared.externalUniversalLinkURL
        )

        let viewModelFactory = GiftPrepareShareViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            universalLinkFactory: universalLinkFactory
        )

        let presenter = GiftPrepareSharePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = GiftPrepareShareViewController(
            presenter: presenter,
            viewStyle: style
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
