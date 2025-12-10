import Foundation
import Foundation_iOS
import Keystore_iOS

struct PVAddConfirmViewFactory {
    static func createOnboardingView(
        with account: PolkadotVaultAccount,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: account,
            type: type,
            wireframe: PVAddConfirmWireframe()
        )
    }

    static func createAddAccountView(
        with account: PolkadotVaultAccount,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: account,
            type: type,
            wireframe: AddAccount.PVAddConfirmWireframe()
        )
    }

    static func createSwitchAccountView(
        with account: PolkadotVaultAccount,
        type: ParitySignerType
    ) -> ControllerBackedProtocol? {
        createView(
            with: account,
            type: type,
            wireframe: SwitchAccount.PVAddConfirmWireframe()
        )
    }

    private static func createView(
        with account: PolkadotVaultAccount,
        type: ParitySignerType,
        wireframe: PVAddConfirmWireframeProtocol
    ) -> ControllerBackedProtocol? {
        let interactor = PVAddConfirmInteractor(
            account: account,
            type: type,
            settings: SelectedWalletSettings.shared,
            pvWalletOperationFactory: ParitySignerWalletOperationFactory(),
            walletOperationFactory: MetaAccountOperationFactory(keystore: Keychain()),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let presenter = PVAddConfirmPresenter(
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
