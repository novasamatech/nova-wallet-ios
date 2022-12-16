import Foundation
import SoraKeystore
import SoraFoundation
import SubstrateSdk
import RobinHood

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
}

final class ServiceCoordinator {
    let walletSettings: SelectedWalletSettings
    let accountInfoService: AccountInfoUpdatingServiceProtocol
    let assetsService: AssetsUpdatingServiceProtocol
    let evmAssetsService: AssetsUpdatingServiceProtocol
    let githubPhishingService: ApplicationServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        assetsService: AssetsUpdatingServiceProtocol,
        evmAssetsService: AssetsUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.assetsService = assetsService
        self.evmAssetsService = evmAssetsService
        self.githubPhishingService = githubPhishingService
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        if let seletedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: seletedMetaAccount)
            assetsService.update(selectedMetaAccount: seletedMetaAccount)
            evmAssetsService.update(selectedMetaAccount: seletedMetaAccount)
        }
    }

    func setup() {
        githubPhishingService.setup()
        accountInfoService.setup()
        assetsService.setup()
        evmAssetsService.setup()
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
        assetsService.throttle()
        evmAssetsService.throttle()
    }
}

extension ServiceCoordinator {
    static func createDefault() -> ServiceCoordinatorProtocol {
        let githubPhishingAPIService = GitHubPhishingServiceFactory.createService()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let logger = Logger.shared

        let assetsOperationQueue = OperationManagerFacade.assetsSyncQueue
        let assetsOperationManager = OperationManager(operationQueue: assetsOperationQueue)

        let walletSettings = SelectedWalletSettings.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let walletRemoteSubscription = WalletServiceFacade.sharedRemoteSubscriptionService
        let evmWalletRemoteSubscription = WalletServiceFacade.sharedEvmRemoteSubscriptionService

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: assetsOperationManager
        )

        let accountInfoService = AccountInfoUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            storageFacade: substrateStorageFacade,
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationQueue: assetsOperationQueue,
            logger: logger
        )

        let assetsService = AssetsUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            storageFacade: substrateStorageFacade,
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationQueue: assetsOperationQueue,
            logger: logger
        )

        let evmTransactionHistoryUpdaterFactory = EvmTransactionHistoryUpdaterFactory(
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationQueue: assetsOperationQueue,
            logger: logger
        )

        let evmAssetsService = EvmAssetBalanceUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: evmWalletRemoteSubscription,
            transactionHistoryUpdaterFactory: evmTransactionHistoryUpdaterFactory,
            logger: logger
        )

        return ServiceCoordinator(
            walletSettings: walletSettings,
            accountInfoService: accountInfoService,
            assetsService: assetsService,
            evmAssetsService: evmAssetsService,
            githubPhishingService: githubPhishingAPIService
        )
    }
}
