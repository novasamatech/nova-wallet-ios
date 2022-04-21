import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe()
        let keychain = Keychain()
        let settings = SettingsManager.shared

        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )

        let interactor = RootInteractor(
            settings: SelectedWalletSettings.shared,
            keystore: keychain,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: EventCenter.shared,
            migrators: [dbMigrator],
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
