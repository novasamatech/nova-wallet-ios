import Foundation
import SoraKeystore
import SoraFoundation
import SubstrateSdk

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
}

final class ServiceCoordinator {
    let walletSettings: SelectedWalletSettings
    let accountInfoService: AccountInfoUpdatingServiceProtocol
    let githubPhishingService: ApplicationServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.githubPhishingService = githubPhishingService
    }

    private func setup(chainRegistry: ChainRegistryProtocol) {
        chainRegistry.syncUp()

        let semaphore = DispatchSemaphore(value: 0)

        chainRegistry.chainsSubscribe(self, runningInQueue: DispatchQueue.global()) { changes in
            if !changes.isEmpty {
                semaphore.signal()
            }
        }

        semaphore.wait()
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        if let seletedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: seletedMetaAccount)
        }
    }

    func setup() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        setup(chainRegistry: chainRegistry)

        githubPhishingService.setup()
        accountInfoService.setup()
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
    }
}

extension ServiceCoordinator {
    static func createDefault() -> ServiceCoordinatorProtocol {
        let githubPhishingAPIService = GitHubPhishingServiceFactory.createService()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.sharedManager
        let walletSettings = SelectedWalletSettings.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let walletRemoteSubscription = WalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager,
            logger: logger
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let accountInfoService = AccountInfoUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            storageFacade: substrateStorageFacade,
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationManager: operationManager,
            logger: logger
        )

        return ServiceCoordinator(
            walletSettings: walletSettings,
            accountInfoService: accountInfoService,
            githubPhishingService: githubPhishingAPIService
        )
    }
}
