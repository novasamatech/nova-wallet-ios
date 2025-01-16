import Foundation
import Foundation_iOS

struct ParitySignerAddConfirmViewFactory {
    static func createOnboardingView(
        with substrateAccountId: AccountId,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: substrateAccountId,
            type: type,
            wireframe: ParitySignerAddConfirmWireframe()
        )
    }

    static func createAddAccountView(
        with substrateAccountId: AccountId,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: substrateAccountId,
            type: type,
            wireframe: AddAccount.ParitySignerAddConfirmWireframe()
        )
    }

    static func createSwitchAccountView(
        with substrateAccountId: AccountId,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: substrateAccountId,
            type: type,
            wireframe: SwitchAccount.ParitySignerAddConfirmWireframe()
        )
    }

    private static func createView(
        with substrateAccountId: AccountId,
        type: ParitySignerType,
        wireframe: ParitySignerAddConfirmWireframeProtocol
    ) -> ControllerBackedProtocol? {
        let interactor = ParitySignerAddConfirmInteractor(
            substrateAccountId: substrateAccountId,
            type: type,
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
