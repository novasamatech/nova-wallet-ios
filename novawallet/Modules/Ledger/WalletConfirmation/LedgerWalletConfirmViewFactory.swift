import Foundation
import Foundation_iOS
import Keystore_iOS

struct LedgerWalletConfirmViewFactory {
    static func createLegacyView(
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

        return createView(with: interactor, flow: flow)
    }

    static func createGenericView(
        for model: PolkadotLedgerWalletModel,
        flow: WalletCreationFlow
    ) -> ControllerBackedProtocol? {
        let interactor = GenericLedgerWalletConfirmInteractor(
            model: model,
            walletOperationFactory: GenericLedgerWalletOperationFactory(),
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            keystore: Keychain(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return createView(with: interactor, flow: flow)
    }

    private static func createView(
        with interactor: BaseLedgerWalletConfirmInteractor & LedgerWalletConfirmInteractorInputProtocol,
        flow: WalletCreationFlow
    ) -> ControllerBackedProtocol? {
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
