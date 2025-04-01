import Keystore_iOS

protocol OpenScreenUrlParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol?
}

final class OpenScreenUrlParsingServiceFactory: OpenScreenUrlParsingServiceFactoryProtocol {
    private let chainRegistryClosure: ChainRegistryLazyClosure
    private let applicationConfig: ApplicationConfigProtocol
    private let settings: SettingsManagerProtocol

    enum Screen: String {
        case staking
        case governance = "gov"
        case dApp = "dapp"
    }

    init(
        chainRegistryClosure: @escaping ChainRegistryLazyClosure,
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
        settings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        self.chainRegistryClosure = chainRegistryClosure
        self.applicationConfig = applicationConfig
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
            return OpenDAppUrlParsingService()
        default:
            return nil
        }
    }
}
