import Foundation
import Foundation_iOS
import Operation_iOS

struct GiftHistoryCheckViewFactory {
    static func createView(
        stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> GiftHistoryCheckViewProtocol? {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let repository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createGiftsRepository(for: selectedWallet.metaId)

        let interactor = GiftHistoryCheckInteractor(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = GiftHistoryCheckWireframe(
            stateObservable: stateObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )

        let localizationManager = LocalizationManager.shared

        let presenter = GiftHistoryCheckPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = GiftHistoryCheckViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
