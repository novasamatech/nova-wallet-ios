import Foundation
import SoraFoundation
import SoraKeystore

struct LedgerWalletConfirmViewFactory {
    static func createView(
        with accountsStore: LedgerAccountsStore,
        flow: WalletCreationFlow
    ) -> ControllerBackedProtocol? {
        let interactor = LedgerWalletConfirmInteractor(
            accountsStore: accountsStore,
            settings: SelectedWalletSettings.shared,
            walletFactory: LedgerWalletFactory(),
            eventCenter: EventCenter.shared,
            keystore: Keychain(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = LedgerWalletConfirmWireframe(flow: flow)

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
