import Foundation
import SoraFoundation

struct ParitySignerAddConfirmViewFactory {
    static func createOnboardingView(with substrateAccountId: AccountId) -> ControllerBackedProtocol? {
        createView(with: substrateAccountId, wireframe: ParitySignerAddConfirmWireframe())
    }

    static func createAddAccountView(with substrateAccountId: AccountId) -> ControllerBackedProtocol? {
        createView(with: substrateAccountId, wireframe: AddAccount.ParitySignerAddConfirmWireframe())
    }

    static func createSwitchAccountView(with substrateAccountId: AccountId) -> ControllerBackedProtocol? {
        createView(with: substrateAccountId, wireframe: SwitchAccount.ParitySignerAddConfirmWireframe())
    }

    private static func createView(
        with substrateAccountId: AccountId,
        wireframe: ParitySignerAddConfirmWireframeProtocol
    ) -> ControllerBackedProtocol? {
        let interactor = ParitySignerAddConfirmInteractor(
            substrateAccountId: substrateAccountId,
            settings: SelectedWalletSettings.shared,
            walletOperationFactory: ParitySignerWalletOperationFactory(),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let presenter = ParitySignerAddConfirmPresenter(
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
