import Foundation
import SoraFoundation

struct LedgerWalletConfirmViewFactory {
    static func createView(with accountsStore: LedgerAccountsStore) -> ControllerBackedProtocol? {
        let interactor = LedgerWalletConfirmInteractor(
            accountsStore: accountsStore,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = LedgerWalletConfirmWireframe()

        let presenter = LedgerWalletConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = UserNameSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
