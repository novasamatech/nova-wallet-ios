protocol OpenScreenUrlParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol?
}

final class OpenScreenUrlParsingServiceFactory: OpenScreenUrlParsingServiceFactoryProtocol {
    private let chainRegistryClosure: ChainRegistryLazyClosure

    enum Screen: String {
        case staking
        case governance = "gov"
        case dApp = "dapp"
    }

    init(chainRegistryClosure: @escaping ChainRegistryLazyClosure) {
        self.chainRegistryClosure = chainRegistryClosure
    }

    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol? {
        switch Screen(rawValue: screen.lowercased()) {
        case .staking:
            return OpenStakingUrlParsingService()
        case .governance:
            return OpenGovernanceUrlParsingService(chainRegistryClosure: chainRegistryClosure)
        case .dApp:
            return OpenDAppUrlParsingService()
        default:
            return nil
        }
    }
}
