import UIKit
import Foundation_iOS
import Operation_iOS
import Keystore_iOS

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1

    static func createView() -> MainTabBarViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let preSyncServiceCoordinator = PreSyncServiceCoordinator.createDefault()
        let serviceCoordinator = ServiceCoordinator.createDefault(for: URLHandlingServiceFacade.shared)

        guard
            let interactor = createInteractor(
                preSyncServiceCoordinator: preSyncServiceCoordinator,
                serviceCoordinator: serviceCoordinator
            ),
            let indexedControllers = createIndexedControllers(
                localizationManager: localizationManager,
                serviceCoordinator: serviceCoordinator,
                preSyncServiceCoordinator: preSyncServiceCoordinator
            )
        else { return nil }

        let presenter = MainTabBarPresenter(localizationManager: LocalizationManager.shared)

        let view = MainTabBarViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        view.viewControllers = indexedControllers.map(\.1)

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
            secretImportService: secretImportService,
            walletMigrationService: walletMigrateService,
            screenOpenService: screenOpenService,
            notificationsPromoService: notificationsPromoService,
            pushScreenOpenService: pushScreenOpenService,
            cloudBackupMediator: CloudBackupSyncMediatorFacade.sharedMediator,
            securedLayer: securedLayer,
            inAppUpdatesService: inAppUpdatesService,
            settingsManager: settingsManager,
            operationQueue: operationQueue,
            logger: logger
        )

        return interactor
    }

    static func createIndexedControllers(
        localizationManager: LocalizationManagerProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        preSyncServiceCoordinator _: PreSyncServiceCoordinatorProtocol
    ) -> [(Int, UIViewController)]? {
        let dAppMediator = serviceCoordinator.dappMediator
        let walletNotificationService = serviceCoordinator.walletNotificationService
        let delegatedAccountSyncService = serviceCoordinator.delegatedAccountSyncService

        guard
            let walletController = createWalletController(
                for: localizationManager,
                dAppMediator: dAppMediator,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService
            ),
            let stakingController = createStakingController(
                for: localizationManager,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService
            ),
            let voteController = createVoteController(
                for: localizationManager,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService
            ),
            let dappsController = createDappsController(
                for: localizationManager,
                walletNotificationService: walletNotificationService,
                delegatedAccountSyncService: delegatedAccountSyncService
            ),
            let settingsController = createProfileController(
                for: localizationManager,
                serviceCoordinator: serviceCoordinator
            )
        else {
            return nil
        }

        return [
            (MainTabBarIndex.wallet, walletController),
            (MainTabBarIndex.vote, voteController),
            (MainTabBarIndex.dapps, dappsController),
            (MainTabBarIndex.staking, stakingController),
            (MainTabBarIndex.settings, settingsController)
        ].sorted { cont1, cont2 in
            cont1.0 < cont2.0
        }
    }

    static func createWalletController(
        for localizationManager: LocalizationManagerProtocol,
        dAppMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        guard let viewController = AssetListViewFactory.createView(
            dAppMediator: dAppMediator,
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        )?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarAssetsTitle()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let iconImage = R.image.iconTabNewYearAssets()

        let selectedColor = R.color.colorTabNewYearAssets()!

        let commonIcon = iconImage?.tinted(with: R.color.colorIconNavbarInactive()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = iconImage?.tinted(with: selectedColor)?
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
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        let viewController = StakingDashboardViewFactory.createView(
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        )?.controller ?? UIViewController()

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarStakingTitle()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let iconImage = R.image.iconTabNewYearStaking()

        let selectedColor = R.color.colorTabNewYearStaking()!

        let commonIcon = iconImage?.tinted(with: R.color.colorIconNavbarInactive()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = iconImage?.tinted(with: selectedColor)?
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

    static func createProfileController(
        for localizationManager: LocalizationManagerProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> UIViewController? {
        guard let view = SettingsViewFactory.createView(
            with: serviceCoordinator
        ) else { return nil }

        let viewController = view.controller

        let navigationController = NovaNavigationController(rootViewController: viewController)

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarSettingsTitle()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let iconImage = R.image.iconTabNewYearSettings()

        let selectedColor = R.color.colorTabNewYearSettings()!

        let commonIcon = iconImage?.tinted(with: R.color.colorIconNavbarInactive()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = iconImage?.tinted(with: selectedColor)?
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

    static func createVoteController(
        for localizationManager: LocalizationManagerProtocol,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        guard let view = VoteViewFactory.createView(
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        ) else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: view.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.tabbarVoteTitle()
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let iconImage = R.image.iconTabNewYearVote()

        let selectedColor = R.color.colorTabNewYearVote()!

        let commonIcon = iconImage?.tinted(with: R.color.colorIconNavbarInactive()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = iconImage?.tinted(with: selectedColor)?
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
        let iconImage = R.image.iconTabNewYearBrowser()

        let selectedColor = R.color.colorTabNewYearBrowser()!

        let commonIcon = iconImage?.tinted(with: R.color.colorIconNavbarInactive()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = iconImage?.tinted(with: selectedColor)?
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
        UITabBarItem(
            title: title,
            image: normalImage,
            selectedImage: selectedImage
        )
    }
}
