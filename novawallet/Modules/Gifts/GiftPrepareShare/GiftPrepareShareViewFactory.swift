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
        guard
            let currencyManager = CurrencyManager.shared,
            let selectedWallet = SelectedWalletSettings.shared.value
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let storageFacade = UserDataStorageFacade.shared
        let repositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let giftRepository = repositoryFactory.createGiftsRepository(for: nil)

        let giftFactory = LocalGiftFactory(
            metaId: selectedWallet.metaId,
            keystore: Keychain()
        )

        let interactor = GiftPrepareShareInteractor(
            giftRepository: giftRepository,
            localGiftFactory: giftFactory,
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

        let viewModelFactory = GiftPrepareShareViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            assetIconViewModelFactory: AssetIconViewModelFactory()
        )

        let presenter = GiftPrepareSharePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            universalLinkFactory: ExternalLinkFactory(baseUrl: ApplicationConfig.shared.externalUniversalLinkURL),
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
