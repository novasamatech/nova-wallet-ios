import UIKit
import Keystore_iOS
import Foundation_iOS

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe(inAppUpdatesServiceFactory: InAppUpdatesServiceFactory())
        let keychain = Keychain()
        let settings = SettingsManager.shared

        let userDatabaseMigrator = createUserDatabaseMigration(
            for: settings,
            keychain: keychain
        )

        let substrateDatabaseMigrator = createSubstrateDatabaseMigration()

        let sharedSettingsMigrator = SharedSettingsMigrator(
            settingsManager: SettingsManager.shared,
            sharedSettingsManager: SharedSettingsManager()
        )

        let interactor = RootInteractor(
            walletSettings: SelectedWalletSettings.shared,
            settings: settings,
            keystore: keychain,
            applicationConfig: ApplicationConfig.shared,
            securityLayerInteractor: SecurityLayerService.shared.interactor,
            chainRegistryClosure: { ChainRegistryFacade.sharedRegistry },
            eventCenter: EventCenter.shared,
            migrators: [sharedSettingsMigrator, userDatabaseMigrator, substrateDatabaseMigrator],
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }

    static func createUserDatabaseMigration(
        for settings: SettingsManagerProtocol,
        keychain: KeystoreProtocol
    ) -> Migrating {
        let storePathMigrator = StorePathMigrator(
            currentStoreLocation: UserStorageParams.deprecatedStorageURL,
            sharedStoreLocation: UserStorageParams.sharedStorageURL,
            sharedStoreDirectory: UserStorageParams.sharedStorageDirectoryURL,
            fileManager: FileManager.default
        )

        let storageMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.sharedStorageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )

        return SerialMigrator(migrations: [storePathMigrator, storageMigrator])
    }

    static func createSubstrateDatabaseMigration() -> Migrating {
        let storePathMigrator = StorePathMigrator(
            currentStoreLocation: SubstrateStorageParams.deprecatedStorageURL,
            sharedStoreLocation: SubstrateStorageParams.sharedStorageURL,
            sharedStoreDirectory: SubstrateStorageParams.sharedStorageDirectoryURL,
            fileManager: FileManager.default
        )

        let storageMigrator = SubstrateStorageMigrator(
            storeURL: SubstrateStorageParams.sharedStorageURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            model: SubstrateStorageParams.modelVersion,
            fileManager: FileManager.default
        )

        return SerialMigrator(migrations: [storePathMigrator, storageMigrator])
    }
}
