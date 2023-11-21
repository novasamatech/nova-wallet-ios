protocol DeeplinkOpenScreenParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> DeeplinkOpenScreenParsingServiceProtocol?
}

final class DeeplinkOpenScreenParsingServiceFactory: DeeplinkOpenScreenParsingServiceFactoryProtocol {
    private let registryClosure: ChainRegistryLazyClosure

    init(registryClosure: @escaping ChainRegistryLazyClosure) {
        self.registryClosure = registryClosure
    }

    func createUrlHandler(screen: String) -> DeeplinkOpenScreenParsingServiceProtocol? {
        switch screen.lowercased() {
        case "staking":
            return StakingUrlHandlingScreen()
        case "gov":
            return GovUrlHandlingScreen(registryClosure: registryClosure)
        default:
            return nil
        }
    }
}
