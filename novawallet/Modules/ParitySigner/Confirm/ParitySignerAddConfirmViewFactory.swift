import Foundation
import Foundation_iOS

struct ParitySignerAddConfirmViewFactory {
    static func createOnboardingView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: walletUpdate,
            type: type,
            wireframe: ParitySignerAddConfirmWireframe()
        )
    }

    static func createAddAccountView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: walletUpdate,
            type: type,
            wireframe: AddAccount.ParitySignerAddConfirmWireframe()
        )
    }

    static func createSwitchAccountView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: walletUpdate,
            type: type,
            wireframe: SwitchAccount.ParitySignerAddConfirmWireframe()
        )
    }

    private static func createView(
        with walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType,
        wireframe: ParitySignerAddConfirmWireframeProtocol
    ) -> ControllerBackedProtocol? {
        let interactor = ParitySignerAddConfirmInteractor(
            walletUpdate: walletUpdate,
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
