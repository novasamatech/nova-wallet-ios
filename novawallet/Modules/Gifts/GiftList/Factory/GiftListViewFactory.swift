import Foundation
import Foundation_iOS
import Operation_iOS

struct GiftListViewFactory {
    static func createView(
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> GiftListViewProtocol? {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let logger = Logger.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let storageFacade = UserDataStorageFacade.shared

        let giftRepository = AccountRepositoryFactory(
            storageFacade: storageFacade
        ).createGiftsRepository(for: selectedWallet.metaId)

        let giftsLocalSubscriptionFactory = GiftsLocalSubscriptionFactory.shared

        let giftSyncService = GiftsSyncService(
            chainRegistry: chainRegistry,
            giftsLocalSubscriptionFactory: giftsLocalSubscriptionFactory,
            assetStorageOperationFactory: AssetStorageInfoOperationFactory(),
            giftRepository: AnyDataProviderRepository(giftRepository),
            operationQueue: operationQueue,
            workingQueue: .main,
            logger: logger
        )

        let interactor = GiftListInteractor(
            giftsLocalSubscriptionFactory: giftsLocalSubscriptionFactory,
            giftSyncService: giftSyncService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = GiftListWireframe(
            stateObservable: stateObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )

        let localizationManager = LocalizationManager.shared

        let presenter = GiftListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            onboardingViewModelFactory: GiftsOnboardingViewModelFactory(),
            learnMoreUrl: ApplicationConfig.shared.giftsWikiURL,
            localizationManager: localizationManager
        )

        let view = GiftListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
