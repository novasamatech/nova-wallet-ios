import Foundation
import Foundation_iOS
import Operation_iOS

struct GiftListViewFactory {
    static func createView(
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> GiftListViewProtocol? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared
        else {
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
        let generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory.shared

        let walletSubscriptionFactory = WalletRemoteSubscriptionFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )

        let statusTrackerQueue = DispatchQueue(
            label: "io.novasama.gift.status.tracking.queue.\(UUID().uuidString)",
            qos: .utility
        )
        let statusTracker = GiftsStatusTracker(
            chainRegistry: chainRegistry,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            walletSubscriptionFactory: walletSubscriptionFactory,
            workingQueue: statusTrackerQueue,
            logger: logger
        )

        let giftSyncService = GiftsSyncService(
            giftsLocalSubscriptionFactory: giftsLocalSubscriptionFactory,
            giftRepository: AnyDataProviderRepository(giftRepository),
            statusTracker: statusTracker,
            operationQueue: operationQueue,
            logger: logger
        )

        let interactor = GiftListInteractor(
            chainRegistry: chainRegistry,
            giftsLocalSubscriptionFactory: giftsLocalSubscriptionFactory,
            giftSyncService: giftSyncService,
            selectedMetaId: selectedWallet.metaId,
            operationQueue: operationQueue
        )

        let wireframe = GiftListWireframe(
            stateObservable: stateObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let giftListViewModelFactory = GiftListViewModelFactory(
            balanceViewModelFacade: balanceViewModelFacade,
            assetIconViewModelFactory: AssetIconViewModelFactory()
        )

        let presenter = GiftListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            onboardingViewModelFactory: GiftsOnboardingViewModelFactory(),
            giftListViewModelFactory: giftListViewModelFactory,
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
