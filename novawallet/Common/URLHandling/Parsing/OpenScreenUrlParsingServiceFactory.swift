protocol OpenScreenUrlParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol?
}

final class OpenScreenUrlParsingServiceFactory: OpenScreenUrlParsingServiceFactoryProtocol {
    private let chainRegistryClosure: ChainRegistryLazyClosure
    private let settings: ApplicationConfigProtocol
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol

    enum Screen: String {
        case staking
        case governance = "gov"
        case dApp = "dapp"
    }

    init(
        chainRegistryClosure: @escaping ChainRegistryLazyClosure,
        settings: ApplicationConfigProtocol = ApplicationConfig.shared,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol = JsonDataProviderFactory.shared
    ) {
        self.chainRegistryClosure = chainRegistryClosure
        self.settings = settings
        self.jsonDataProviderFactory = jsonDataProviderFactory
    }

    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol? {
        switch Screen(rawValue: screen.lowercased()) {
        case .staking:
            return OpenStakingUrlParsingService()
        case .governance:
            let chainRegistry = chainRegistryClosure()
            return OpenGovernanceUrlParsingService(chainRegistry: chainRegistry)
        case .dApp:
            let dAppsProvider: AnySingleValueProvider<DAppList> = jsonDataProviderFactory.getJson(
                for: settings.dAppsListURL)
            return OpenDAppUrlParsingService(dAppsProvider: dAppsProvider)
        default:
            return nil
        }
    }
}
