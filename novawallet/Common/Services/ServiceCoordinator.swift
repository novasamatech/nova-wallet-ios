import Foundation
import SoraKeystore
import SoraFoundation
import SubstrateSdk
import RobinHood

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    var dappMediator: DAppInteractionMediating { get }
    var walletNotificationService: WalletNotificationServiceProtocol { get }
    var proxySyncService: ProxySyncServiceProtocol { get }

    func updateOnWalletSelectionChange()

    func updateOnWalletChange()
}

final class ServiceCoordinator {
    let walletSettings: SelectedWalletSettings
    let accountInfoService: AccountInfoUpdatingServiceProtocol
    let assetsService: AssetsUpdatingServiceProtocol
    let evmAssetsService: AssetsUpdatingServiceProtocol
    let evmNativeService: AssetsUpdatingServiceProtocol
    let githubPhishingService: ApplicationServiceProtocol
    let equilibriumService: AssetsUpdatingServiceProtocol
    let dappMediator: DAppInteractionMediating
    let proxySyncService: ProxySyncServiceProtocol
    let walletNotificationService: WalletNotificationServiceProtocol
    let syncModeUpdateService: ChainSyncModeUpdateServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        assetsService: AssetsUpdatingServiceProtocol,
        evmAssetsService: AssetsUpdatingServiceProtocol,
        evmNativeService: AssetsUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        equilibriumService: AssetsUpdatingServiceProtocol,
        proxySyncService: ProxySyncServiceProtocol,
        dappMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        syncModeUpdateService: ChainSyncModeUpdateServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.assetsService = assetsService
        self.evmAssetsService = evmAssetsService
        self.evmNativeService = evmNativeService
        self.equilibriumService = equilibriumService
        self.githubPhishingService = githubPhishingService
        self.proxySyncService = proxySyncService
        self.dappMediator = dappMediator
        self.walletNotificationService = walletNotificationService
        self.syncModeUpdateService = syncModeUpdateService
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnWalletSelectionChange() {
        if let selectedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: selectedMetaAccount)
            assetsService.update(selectedMetaAccount: selectedMetaAccount)
            evmAssetsService.update(selectedMetaAccount: selectedMetaAccount)
            evmNativeService.update(selectedMetaAccount: selectedMetaAccount)
            equilibriumService.update(selectedMetaAccount: selectedMetaAccount)
            syncModeUpdateService.update(selectedMetaAccount: selectedMetaAccount)
        }
    }

    func updateOnWalletChange() {
        proxySyncService.syncUp()
    }

    func setup() {
        githubPhishingService.setup()
        accountInfoService.setup()
        assetsService.setup()
        evmAssetsService.setup()
        evmNativeService.setup()
        equilibriumService.setup()
        proxySyncService.setup()
        dappMediator.setup()
        syncModeUpdateService.setup()
        walletNotificationService.setup()
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
        assetsService.throttle()
        evmAssetsService.throttle()
        evmNativeService.throttle()
        equilibriumService.throttle()
        proxySyncService.throttle()
        dappMediator.throttle()
        syncModeUpdateService.throttle()
        walletNotificationService.throttle()
    }
}

extension ServiceCoordinator {
    // swiftlint:disable:next function_body_length
    static func createDefault(for urlHandlingFacade: URLHandlingServiceFacadeProtocol) -> ServiceCoordinatorProtocol {
        let githubPhishingAPIService = GitHubPhishingServiceFactory.createService()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let logger = Logger.shared

        let assetsSyncOperationQueue = OperationManagerFacade.assetsSyncQueue
        let assetsSyncOperationManager = OperationManager(operationQueue: assetsSyncOperationQueue)

        let assetsRepositoryOperationQueue = OperationManagerFacade.assetsRepositoryQueue

        let walletSettings = SelectedWalletSettings.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let walletRemoteSubscription = WalletServiceFacade.sharedRemoteSubscriptionService
        let evmWalletRemoteSubscription = WalletServiceFacade.sharedEvmRemoteSubscriptionService

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: assetsSyncOperationManager
        )

        let userDataStorageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: userDataStorageFacade)
        let metaAccountsRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let accountInfoService = AccountInfoUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            storageFacade: substrateStorageFacade,
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationQueue: assetsRepositoryOperationQueue,
            logger: logger
        )

        let assetsService = AssetsUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            storageFacade: substrateStorageFacade,
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationQueue: assetsRepositoryOperationQueue,
            logger: logger
        )

        let evmTransactionHistoryUpdaterFactory = EvmTransactionHistoryUpdaterFactory(
            storageFacade: substrateStorageFacade,
            chainRegistry: chainRegistry,
            eventCenter: EventCenter.shared,
            operationQueue: assetsSyncOperationQueue,
            logger: logger
        )

        let evmAssetsService = EvmAssetBalanceUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: evmWalletRemoteSubscription,
            transactionHistoryUpdaterFactory: evmTransactionHistoryUpdaterFactory,
            logger: logger
        )

        let evmNativeService = EvmNativeBalanceUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: evmWalletRemoteSubscription,
            transactionHistoryUpdaterFactory: evmTransactionHistoryUpdaterFactory,
            logger: logger
        )

        let equilibriumService = EquilibriumAssetBalanceUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: substrateStorageFacade),
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationQueue(),
            logger: logger
        )

        let walletUpdateMediator = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: metaAccountsRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let proxySyncService = ProxySyncService(
            chainRegistry: chainRegistry,
            proxyOperationFactory: ProxyOperationFactory(),
            metaAccountsRepository: metaAccountsRepository,
            walletUpdateMediator: walletUpdateMediator,
            chainFilter: { chain in
                #if F_RELEASE
                    return chain.hasProxy && !chain.isTestnet
                #else
                    return chain.hasProxy
                #endif
            },
            chainWalletFilter: { _, wallet in
                #if F_RELEASE
                    return wallet.type != .watchOnly
                #else
                    return true
                #endif
            }
        )

        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactory.shared,
            logger: logger
        )

        let syncModeUpdateService = ChainSyncModeUpdateService(
            selectedMetaAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            logger: logger
        )

        return ServiceCoordinator(
            walletSettings: walletSettings,
            accountInfoService: accountInfoService,
            assetsService: assetsService,
            evmAssetsService: evmAssetsService,
            evmNativeService: evmNativeService,
            githubPhishingService: githubPhishingAPIService,
            equilibriumService: equilibriumService,
            proxySyncService: proxySyncService,
            dappMediator: DAppInteractionFactory.createMediator(for: urlHandlingFacade),
            walletNotificationService: walletNotificationService,
            syncModeUpdateService: syncModeUpdateService
        )
    }
}
