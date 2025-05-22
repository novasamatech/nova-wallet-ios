import Foundation
import Keystore_iOS
import NovaCrypto
import Foundation_iOS

struct WalletMigrateAcceptViewFactory {
    static func createView(from message: WalletMigrationMessage.Start) -> WalletMigrateAcceptViewProtocol? {
        guard let interactor = createInteractor(from: message) else {
            return nil
        }

        let wireframe = WalletMigrateAcceptWireframe()

        let presenter = WalletMigrateAcceptPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = WalletMigrateAcceptViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension WalletMigrateAcceptViewFactory {
    static func createInteractor(from startMessage: WalletMigrationMessage.Start) -> WalletMigrateAcceptInteractor? {
        guard
            let urlFacade = URLHandlingServiceFacade.shared,
            let walletMigrateService: WalletMigrationServiceProtocol = urlFacade.findInternalService() else {
            return nil
        }

        return WalletMigrateAcceptInteractor(
            startMessage: startMessage,
            walletMigrationService: walletMigrateService,
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
