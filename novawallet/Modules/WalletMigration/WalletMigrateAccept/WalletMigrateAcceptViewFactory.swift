import Foundation
import Keystore_iOS
import NovaCrypto

struct WalletMigrateAcceptViewFactory {
    static func createView(from message: WalletMigrationMessage.Start) -> WalletMigrateAcceptViewProtocol? {
        let interactor = createInteractor(from: message)
        let wireframe = WalletMigrateAcceptWireframe()

        let presenter = WalletMigrateAcceptPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletMigrateAcceptViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension WalletMigrateAcceptViewFactory {
    static func createInteractor(from startMessage: WalletMigrationMessage.Start) -> WalletMigrateAcceptInteractor {
        WalletMigrateAcceptInteractor(
            startMessage: startMessage,
            sessionManager: SecureSessionManager(),
            settings: SelectedWalletSettings.shared,
            metaAccountOperationFactory: MetaAccountOperationFactory(keystore: Keychain()),
            mnemonicFactory: IRMnemonicCreator(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }
}
