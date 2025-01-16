import Keystore_iOS

protocol OpenScreenUrlParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol?
}

final class OpenScreenUrlParsingServiceFactory: OpenScreenUrlParsingServiceFactoryProtocol {
    private let chainRegistryClosure: ChainRegistryLazyClosure
    private let applicationConfig: ApplicationConfigProtocol
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    private let settings: SettingsManagerProtocol

    enum Screen: String {
        case staking
        case governance = "gov"
        case dApp = "dapp"
    }

    init(
        chainRegistryClosure: @escaping ChainRegistryLazyClosure,
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol = JsonDataProviderFactory.shared,
        settings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        self.chainRegistryClosure = chainRegistryClosure
        self.applicationConfig = applicationConfig
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.settings = settings
    }

    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol? {
        switch Screen(rawValue: screen.lowercased()) {
        case .staking:
            return OpenStakingUrlParsingService()
        case .governance:
            let chainRegistry = chainRegistryClosure()
            return OpenGovernanceUrlParsingService(chainRegistry: chainRegistry, settings: settings)
        case .dApp:
            let dAppsProvider: AnySingleValueProvider<DAppList> = jsonDataProviderFactory.getJson(
                for: applicationConfig.dAppsListURL)
            return OpenDAppUrlParsingService(dAppsProvider: dAppsProvider)
        default:
            return nil
        }
    }
}
