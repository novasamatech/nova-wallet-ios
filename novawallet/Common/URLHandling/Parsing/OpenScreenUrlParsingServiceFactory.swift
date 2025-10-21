import Keystore_iOS
import Foundation

protocol OpenScreenUrlParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol?
}

final class OpenScreenUrlParsingServiceFactory: OpenScreenUrlParsingServiceFactoryProtocol {
    private let chainRegistryClosure: ChainRegistryLazyClosure
    private let applicationConfig: ApplicationConfigProtocol
    private let operationQueue: OperationQueue
    private let settings: SettingsManagerProtocol

    init(
        chainRegistryClosure: @escaping ChainRegistryLazyClosure,
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        settings: SettingsManagerProtocol = SettingsManager.shared
    ) {
        self.chainRegistryClosure = chainRegistryClosure
        self.applicationConfig = applicationConfig
        self.operationQueue = operationQueue
        self.settings = settings
    }

    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol? {
        switch UniversalLink.Screen(rawValue: screen.lowercased()) {
        case .staking:
            return OpenStakingUrlParsingService()
        case .governance:
            let chainRegistry = chainRegistryClosure()
            return OpenGovernanceUrlParsingService(
                chainRegistry: chainRegistry,
                settings: settings
            )
        case .dApp:
            return OpenDAppUrlParsingService()
        case .card:
            return OpenCardUrlParsingService()
        case .assetHubMigration:
            return OpenAHMUrlParsingService(operationQueue: operationQueue)
        default:
            return nil
        }
    }
}
