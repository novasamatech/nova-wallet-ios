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

        let repository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createGiftsRepository(for: selectedWallet.metaId)

        let interactor = GiftListInteractor(
            repository: AnyDataProviderRepository(repository),
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
