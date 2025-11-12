import Keystore_iOS
import Foundation

protocol OpenScreenUrlParsingServiceFactoryProtocol {
    func createUrlHandler(screen: String) -> OpenScreenUrlParsingServiceProtocol?
}

final class OpenScreenUrlParsingServiceFactory {
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
}

// MARK: - Private

private extension OpenScreenUrlParsingServiceFactory {
    func creategiftUrlParsingService() -> OpenScreenUrlParsingServiceProtocol {
        let secretManager = GiftSecretsManager(keystore: Keychain())

        let chainRegistry = chainRegistryClosure()
        let balanceQueryFactory = WalletRemoteQueryWrapperFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        let assetStorageInfoFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        let claimAvailabilityChecker = GiftClaimAvailabilityCheckFactory(
            chainRegistry: chainRegistry,
            giftSecretsManager: secretManager,
            balanceQueryFactory: balanceQueryFactory,
            assetInfoFactory: assetStorageInfoFactory,
            operationQueue: operationQueue
        )

        return ClaimGiftUrlParsingService(
            chainRegistry: chainRegistry,
            claimAvailabilityChecker: claimAvailabilityChecker,
            giftPublicKeyProvider: secretManager,
            operationQueue: operationQueue
        )
    }
}

// MARK: - OpenScreenUrlParsingServiceFactoryProtocol

extension OpenScreenUrlParsingServiceFactory: OpenScreenUrlParsingServiceFactoryProtocol {
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
        case .gift:
            return creategiftUrlParsingService()
        default:
            return nil
        }
    }
}
