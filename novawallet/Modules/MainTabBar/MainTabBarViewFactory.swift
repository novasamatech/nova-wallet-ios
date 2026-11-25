import UIKit
import Foundation_iOS
import Operation_iOS
import Keystore_iOS

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static func createView() -> MainTabBarViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let preSyncServiceCoordinator = PreSyncServiceCoordinator.createDefault()
        let serviceCoordinator = ServiceCoordinator.createDefault(for: URLHandlingServiceFacade.shared)

        guard
            let interactor = createInteractor(
                preSyncServiceCoordinator: preSyncServiceCoordinator,
                serviceCoordinator: serviceCoordinator
            ),
            let controllers = createControllers(
                localizationManager: localizationManager,
                serviceCoordinator: serviceCoordinator
            )
        else { return nil }

        let presenter = MainTabBarPresenter(localizationManager: LocalizationManager.shared)

        let view = MainTabBarViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        view.moreControllers = controllers.moreItems
        view.viewControllers = controllers.tabs

        let wireframe = MainTabBarWireframe(
            cardScreenNavigationFactory: CardScreenNavigationFactory()
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}

// MARK: Private

private extension MainTabBarViewFactory {
    static func createInteractor(
        preSyncServiceCoordinator: PreSyncServiceCoordinatorProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> MainTabBarInteractor? {
        let urlServiceFacade: URLHandlingServiceFacadeProtocol = URLHandlingServiceFacade.shared

        guard
            let secretImportService: SecretImportServiceProtocol = urlServiceFacade.findInternalService(),
            let screenOpenService: ScreenOpenServiceProtocol = urlServiceFacade.findInternalService(),
            let walletMigrateService: WalletMigrationServiceProtocol = urlServiceFacade.findInternalService(),
            let pushScreenOpenService = PushNotificationHandlingService.shared.service else {
            Logger.shared.error("Can't find required service")
            return nil
        }

        let logger = Logger.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let settingsManager = SettingsManager.shared
        let securedLayer = SecurityLayerService.shared

        let inAppUpdatesService = InAppUpdatesServiceFactory().createService()

        let notificationsSettingsRepository: CoreDataRepository<Web3Alert.LocalSettings, CDUserSingleValue> =
            UserDataStorageFacade.shared.createRepository(
                filter: .pushSettings,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(Web3AlertSettingsMapper())
            )

        let notificationsPromoService = MultisigNotificationsPromoService(
            settingsManager: settingsManager,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            notificationsSettingsrepository: AnyDataProviderRepository(notificationsSettingsRepository),
            operationQueue: operationQueue,
            workingQueue: .main,
            logger: logger
        )

        let interactor = MainTabBarInteractor(
            applicationHandler: ApplicationHandler(),
            eventCenter: EventCenter.shared,
            preSyncServiceCoodrinator: preSyncServiceCoordinator,
            serviceCoordinator: serviceCoordinator,
            transactionTrackingFacade: TransactionTrackingFacade.shared,
            secretImportService: secretImportService,
            walletMigrationService: walletMigrateService,
            screenOpenService: screenOpenService,
            notificationsPromoService: notificationsPromoService,
            pushScreenOpenService: pushScreenOpenService,
            cloudBackupMediator: CloudBackupSyncMediatorFacade.sharedMediator,
            securedLayer: securedLayer,
            inAppUpdatesService: inAppUpdatesService,
            settingsManager: settingsManager,
            legalConsentRepository: LegalConsentRepository.shared,
            analyticsConsent: AnalyticsFacadeFactory.createDefault().consent,
            walletSettings: SelectedWalletSettings.shared,
            operationQueue: operationQueue,
            logger: logger
        )

        return interactor
    }

    static func createControllers(
        localizationManager: LocalizationManagerProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> (tabs: [UIViewController], moreItems: [MainTabBarMoreItem: UIViewController])? {
        let dAppMediator = serviceCoordinator.dappMediator
        let walletNotificationService = serviceCoordinator.walletNotificationService
        let delegatedAccountSyncService = serviceCoordinator.delegatedAccountSyncService
        let assetListObservable = AssetListModelObservable(state: .init(value: .init()))

        guard
            let walletController = createWalletController(
                for: localizationManager,
                dAppMediator: dAppMediator,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService,
                assetListObservable: assetListObservable
            ),
            let stakingController = createStakingController(
                for: localizationManager,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService,
                assetListObservable: assetListObservable
            ),
            let voteController = createVoteController(
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService
            ),
            let dappsController = createDappsController(
                for: localizationManager,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService
            ),
            let settingsController = createProfileController(serviceCoordinator: serviceCoordinator)
        else {
            return nil
        }

        let swapsController = createSwapsController(
            for: localizationManager,
            assetListObservable: assetListObservable
        )

        let moreTabBarItem = createMoreTabBarItem(for: localizationManager)
        voteController.tabBarItem = moreTabBarItem
        settingsController.tabBarItem = moreTabBarItem

        let tabs = [
            (MainTabBarIndex.wallet, walletController),
            (MainTabBarIndex.dapps, dappsController),
            (MainTabBarIndex.swaps, swapsController),
            (MainTabBarIndex.staking, stakingController),
            (MainTabBarIndex.more, voteController)
        ].sorted { cont1, cont2 in
            cont1.0 < cont2.0
        }.map(\.1)

        return (tabs, [.governance: voteController, .settings: settingsController])
    }

    static func createWalletController(
        for localizationManager: LocalizationManagerProtocol,
        dAppMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        assetListObservable: AssetListModelObservable
    ) -> UIViewController? {
        guard let viewController = AssetListViewFactory.createView(
            dAppMediator: dAppMediator,
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService,
            assetListModelObservable: assetListObservable
        )?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarAssetsTitle()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let commonIconImage = R.image.iconTabWallet()
        let selectedIconImage = R.image.iconTabWalletFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorIconPrimary()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorIconAccent()!)?
            .withRenderingMode(.alwaysOriginal)

        viewController.tabBarItem = createTabBarItem(
            title: currentTitle,
            normalImage: commonIcon,
            selectedImage: selectedIcon
        )

        localizationManager.addObserver(with: viewController) { [weak viewController] _, _ in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        let navigationController = NovaNavigationController(rootViewController: viewController)

        return navigationController
    }

    static func createStakingController(
        for localizationManager: LocalizationManagerProtocol,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        assetListObservable: AssetListModelObservable
    ) -> UIViewController? {
        let viewController = StakingDashboardViewFactory.createView(
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService,
            assetListObservable: assetListObservable
        )?.controller ?? UIViewController()

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarStakingTitle()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let commonIconImage = R.image.iconTabStaking()
        let selectedIconImage = R.image.iconTabStakingFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorIconPrimary()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorIconAccent()!)?
            .withRenderingMode(.alwaysOriginal)

        viewController.tabBarItem = createTabBarItem(
            title: currentTitle,
            normalImage: commonIcon,
            selectedImage: selectedIcon
        )

        localizationManager.addObserver(with: viewController) { [weak viewController] _, _ in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            viewController?.tabBarItem.title = currentTitle
        }

        let navigationController = NovaNavigationController(rootViewController: viewController)

        return navigationController
    }

    static func createProfileController(serviceCoordinator: ServiceCoordinatorProtocol) -> UIViewController? {
        guard let view = SettingsViewFactory.createView(
            with: serviceCoordinator
        ) else { return nil }

        return NovaNavigationController(rootViewController: view.controller)
    }

    static func createVoteController(
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        guard let view = VoteViewFactory.createView(
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        ) else {
            return nil
        }

        return NovaNavigationController(rootViewController: view.controller)
    }

    static func createSwapsController(
        for localizationManager: LocalizationManagerProtocol,
        assetListObservable: AssetListModelObservable
    ) -> UIViewController {
        let viewController = SwapsTabHostViewController(
            assetListObservable: assetListObservable,
            prefillResolver: SwapSetupViewFactory.createPrefillResolver(),
            pairPrefillResolver: SwapSetupViewFactory.createPrefillResolver(),
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            localizationManager: localizationManager
        )

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarSwapsTitle()
        }

        viewController.tabBarItem = createTabBarItem(
            title: localizableTitle,
            normalIconImage: R.image.iconTabSwaps(),
            selectedIconImage: R.image.iconTabSwapsFilled(),
            localizationManager: localizationManager
        )

        return NovaNavigationController(rootViewController: viewController)
    }

    static func createMoreTabBarItem(for localizationManager: LocalizationManagerProtocol) -> UITabBarItem {
        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarMoreTitle()
        }

        return createTabBarItem(
            title: localizableTitle,
            normalIconImage: R.image.iconTabMore(),
            selectedIconImage: R.image.iconMore(),
            localizationManager: localizationManager
        )
    }

    static func createTabBarItem(
        title localizableTitle: LocalizableResource<String>,
        normalIconImage: UIImage?,
        selectedIconImage: UIImage?,
        localizationManager: LocalizationManagerProtocol
    ) -> UITabBarItem {
        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let commonIcon = normalIconImage?.tinted(with: R.color.colorIconPrimary()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorIconAccent()!)?
            .withRenderingMode(.alwaysOriginal)

        let tabBarItem = createTabBarItem(
            title: currentTitle,
            normalImage: commonIcon,
            selectedImage: selectedIcon
        )

        localizationManager.addObserver(with: tabBarItem) { [weak tabBarItem] _, _ in
            tabBarItem?.title = localizableTitle.value(for: localizationManager.selectedLocale)
        }

        return tabBarItem
    }

    static func createDappsController(
        for localizationManager: LocalizationManagerProtocol,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        guard let dappsView = DAppListViewFactory.createView(
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        ) else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: dappsView.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarDappsTitle_2_4_3()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabDApps()
        let selectedIconImage = R.image.iconTabDAppsFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorIconPrimary()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorIconAccent()!)?
            .withRenderingMode(.alwaysOriginal)

        navigationController.tabBarItem = createTabBarItem(
            title: currentTitle,
            normalImage: commonIcon,
            selectedImage: selectedIcon
        )

        localizationManager.addObserver(with: navigationController) { [weak navigationController] _, _ in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createTabBarItem(
        title: String,
        normalImage: UIImage?,
        selectedImage: UIImage?
    ) -> UITabBarItem {
        UITabBarItem(title: title, image: normalImage, selectedImage: selectedImage)
    }
}
