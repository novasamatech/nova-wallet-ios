import Foundation
import Keystore_iOS
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    var dappMediator: DAppInteractionMediating { get }
    var walletNotificationService: WalletNotificationServiceProtocol { get }
    var delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol { get }

    func updateOnWalletSelectionChange()

    func updateOnWalletChange(for source: WalletsChangeSource)
    func updateOnWalletRemove()
}

final class ServiceCoordinator {
    let walletSettings: SelectedWalletSettings
    let substrateBalancesService: AssetBalanceUpdatingServiceProtocol
    let hydrationEvmBalancesService: AssetBalanceUpdatingServiceProtocol
    let evmAssetsService: AssetBalanceUpdatingServiceProtocol
    let evmNativeService: AssetBalanceUpdatingServiceProtocol
    let githubPhishingService: ApplicationServiceProtocol
    let equilibriumService: AssetBalanceUpdatingServiceProtocol
    let dappMediator: DAppInteractionMediating
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    let walletNotificationService: WalletNotificationServiceProtocol
    let syncModeUpdateService: ChainSyncModeUpdateServiceProtocol
    let pushNotificationsFacade: PushNotificationsServiceFacadeProtocol
    let pendingMultisigSyncService: MultisigPendingOperationsServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        substrateBalancesService: AssetBalanceUpdatingServiceProtocol,
        hydrationEvmBalancesService: AssetBalanceUpdatingServiceProtocol,
        evmAssetsService: AssetBalanceUpdatingServiceProtocol,
        evmNativeService: AssetBalanceUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        equilibriumService: AssetBalanceUpdatingServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        dappMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        syncModeUpdateService: ChainSyncModeUpdateServiceProtocol,
        pushNotificationsFacade: PushNotificationsServiceFacadeProtocol,
        pendingMultisigSyncService: MultisigPendingOperationsServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.substrateBalancesService = substrateBalancesService
        self.hydrationEvmBalancesService = hydrationEvmBalancesService
        self.evmAssetsService = evmAssetsService
        self.evmNativeService = evmNativeService
        self.equilibriumService = equilibriumService
        self.githubPhishingService = githubPhishingService
        self.delegatedAccountSyncService = delegatedAccountSyncService
        self.dappMediator = dappMediator
        self.walletNotificationService = walletNotificationService
        self.syncModeUpdateService = syncModeUpdateService
        self.pushNotificationsFacade = pushNotificationsFacade
        self.pendingMultisigSyncService = pendingMultisigSyncService
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnWalletSelectionChange() {
        if let selectedMetaAccount = walletSettings.value {
            substrateBalancesService.update(selectedMetaAccount: selectedMetaAccount)
            hydrationEvmBalancesService.update(selectedMetaAccount: selectedMetaAccount)
            evmAssetsService.update(selectedMetaAccount: selectedMetaAccount)
            evmNativeService.update(selectedMetaAccount: selectedMetaAccount)
            equilibriumService.update(selectedMetaAccount: selectedMetaAccount)
            syncModeUpdateService.update(selectedMetaAccount: selectedMetaAccount)
            pendingMultisigSyncService.update(selectedMetaAccount: selectedMetaAccount)
        }
    }

    func updateOnWalletChange(for source: WalletsChangeSource) {
        switch source {
        case .byUserManually, .byCloudBackup:
            delegatedAccountSyncService.syncUp()
        case .byProxyService:
            break
        }

        pushNotificationsFacade.syncWallets()
    }

    func updateOnWalletRemove() {
        pushNotificationsFacade.syncWallets()
    }

    func setup() {
        githubPhishingService.setup()
        substrateBalancesService.setup()
        hydrationEvmBalancesService.setup()
        evmAssetsService.setup()
        evmNativeService.setup()
        equilibriumService.setup()
        delegatedAccountSyncService.setup()
        dappMediator.setup()
        syncModeUpdateService.setup()
        walletNotificationService.setup()
        pushNotificationsFacade.setup()
        pendingMultisigSyncService.setup()
    }

    func throttle() {
        githubPhishingService.throttle()
        substrateBalancesService.throttle()
        hydrationEvmBalancesService.throttle()
        evmAssetsService.throttle()
        evmNativeService.throttle()
        equilibriumService.throttle()
        delegatedAccountSyncService.throttle()
        dappMediator.throttle()
        syncModeUpdateService.throttle()
        walletNotificationService.throttle()
        pushNotificationsFacade.throttle()
        pendingMultisigSyncService.throttle()
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

        let walletSettings = SelectedWalletSettings.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

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

        let substrateBalancesService = SubstrateAssetsUpdatingService(
            selectedAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: WalletServiceFacade.sharedSubstrateRemoteSubscriptionService,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        let hydrationEvmBalancesService = OrmlHydrationEvmWalletSyncService(
            selectedAccount: walletSettings.value,
            syncServiceFactory: OrmlHydrationEvmWalletSyncFactory(
                chainRegistry: chainRegistry,
                substrateStorageFacade: substrateStorageFacade,
                transactionSubscriptionFactory: WalletServiceFacade.sharedTransactionSubscriptionFactory,
                operationQueue: OperationManagerFacade.assetsSyncQueue,
                logger: Logger.shared
            ),
            chainRegistry: chainRegistry,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
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
            remoteSubscriptionService: WalletServiceFacade.sharedEquillibriumRemoteSubscriptionService,
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: substrateStorageFacade),
            storageRequestFactory: storageRequestFactory,
            eventCenter: EventCenter.shared,
            operationQueue: assetsSyncOperationQueue,
            logger: logger
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let walletStorageCleaner = WalletStorageCleanerFactory.createWalletStorageCleaner(
            using: operationQueue
        )

        let walletUpdateMediator = WalletUpdateMediator(
            selectedWalletSettings: SelectedWalletSettings.shared,
            repository: metaAccountsRepository,
            walletsCleaner: walletStorageCleaner,
            operationQueue: operationQueue
        )

        let delegatedAccountSyncService = DelegatedAccountSyncService(
            chainRegistry: chainRegistry,
            metaAccountsRepository: metaAccountsRepository,
            walletUpdateMediator: walletUpdateMediator,
            chainFilter: .allSatisfies([.enabledChains, .hasProxy]),
            chainWalletFilter: { wallet in
                #if F_RELEASE
                    return wallet.type != .watchOnly
                #else
                    return true
                #endif
            }
        )

        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactory.shared,
            multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactory.shared,
            logger: logger
        )

        let syncModeUpdateService = ChainSyncModeUpdateService(
            selectedMetaAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            logger: logger
        )

        return ServiceCoordinator(
            walletSettings: walletSettings,
            substrateBalancesService: substrateBalancesService,
            hydrationEvmBalancesService: hydrationEvmBalancesService,
            evmAssetsService: evmAssetsService,
            evmNativeService: evmNativeService,
            githubPhishingService: githubPhishingAPIService,
            equilibriumService: equilibriumService,
            delegatedAccountSyncService: delegatedAccountSyncService,
            dappMediator: DAppInteractionFactory.createMediator(for: urlHandlingFacade),
            walletNotificationService: walletNotificationService,
            syncModeUpdateService: syncModeUpdateService,
            pushNotificationsFacade: PushNotificationsServiceFacade.shared,
            pendingMultisigSyncService: MultisigPendingOperationsService.shared
        )
    }
}
