import UIKit
import Keystore_iOS
import Foundation_iOS
import Kingfisher

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        // goes first for every request of the launch to nova-utils to be read from the config mirror
        registerConfigMirror()

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

        let legacyAttestationStorageMigrator = LegacyAttestationStorageMigrator(
            settingsManager: settings,
            novaAuthKeychainService: ApplicationConfig.shared.novaAuthKeychainService
        )

        let assetVisibilitySeedMigrator = AssetVisibilitySeedMigrator(
            settingsManager: settings,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            userStorageFacade: UserDataStorageFacade.shared,
            workQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let interactor = RootInteractor(
            walletSettings: SelectedWalletSettings.shared,
            settings: settings,
            keystore: keychain,
            applicationConfig: ApplicationConfig.shared,
            securityLayerInteractor: SecurityLayerService.shared.interactor,
            chainRegistryClosure: { ChainRegistryFacade.sharedRegistry },
            eventCenter: EventCenter.shared,
            analyticsFacade: AnalyticsFacadeFactory.createDefault(),
            migrators: [
                sharedSettingsMigrator,
                userDatabaseMigrator,
                substrateDatabaseMigrator,
                assetVisibilitySeedMigrator,
                legacyAttestationStorageMigrator
            ],
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }

    /// `URLSession.shared` and the image downloader are the two ways the app requests nova-utils files
    static func registerConfigMirror() {
        let dependencies = ConfigMirrorURLProtocol.Dependencies(
            urlResolver: ConfigMirrorURLResolver(applicationConfig: ApplicationConfig.shared),
            availability: ConfigMirrorAvailability(),
            loader: ConfigMirrorLoader(),
            logger: Logger.shared
        )

        ConfigMirrorURLProtocol.register(dependencies: dependencies)
        KingfisherManager.shared.downloader.addProtocolClass(ConfigMirrorURLProtocol.self)
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
