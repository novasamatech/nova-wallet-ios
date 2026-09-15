import Foundation
import Keystore_iOS

extension DefaultAssetsProvider {
    private enum Constants {
        static let fetchTimeout: TimeInterval = 10
    }

    static let shared = DefaultAssetsProvider(
        url: ApplicationConfig.shared.defaultAssetsURL,
        dataOperationFactory: DataOperationFactory(
            timeout: Constants.fetchTimeout,
            ignoresCache: true
        ),
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        settingsManager: SettingsManager.shared,
        logger: Logger.shared
    )
}
