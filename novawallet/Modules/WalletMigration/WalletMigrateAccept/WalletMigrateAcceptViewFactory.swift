import Foundation
import Keystore_iOS
import NovaCrypto
import Foundation_iOS

struct WalletMigrateAcceptViewFactory {
    static func createViewForOnboarding(
        from message: WalletMigrationMessage.Start
    ) -> WalletMigrateAcceptViewProtocol? {
        createView(from: message, wireframe: WalletMigrateAcceptWhenOnboardWireframe())
    }

    static func createViewForAdding(
        from message: WalletMigrationMessage.Start
    ) -> WalletMigrateAcceptViewProtocol? {
        createView(from: message, wireframe: WalletMigrateAcceptWhenAddWireframe())
    }
}

private extension WalletMigrateAcceptViewFactory {
    static func createView(
        from message: WalletMigrationMessage.Start,
        wireframe: WalletMigrateAcceptWireframeProtocol
    ) -> WalletMigrateAcceptViewProtocol? {
        guard let interactor = createInteractor(from: message) else {
            return nil
        }

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

    static func createInteractor(from startMessage: WalletMigrationMessage.Start) -> WalletMigrateAcceptInteractor? {
        guard
            let urlFacade = URLHandlingServiceFacade.shared,
            let walletMigrateService: WalletMigrationServiceProtocol = urlFacade.findInternalService() else {
            return nil
        }

        return WalletMigrateAcceptInteractor(
            startMessage: startMessage,
            cloudBackupSyncService: CloudBackupSyncMediatorFacade.sharedMediator.syncService,
            walletMigrationService: walletMigrateService,
            sessionManager: SecureSessionManager.createForWalletMigration(),
            settings: SelectedWalletSettings.shared,
            metaAccountOperationFactory: MetaAccountOperationFactory(keystore: Keychain()),
            mnemonicFactory: IRMnemonicCreator(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }
}
