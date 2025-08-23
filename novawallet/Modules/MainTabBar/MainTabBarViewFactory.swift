import UIKit
import Foundation_iOS
import Keystore_iOS

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1

    static func createView() -> MainTabBarViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let serviceCoordinator = ServiceCoordinator.createDefault(for: URLHandlingServiceFacade.shared)

        guard
            let interactor = createInteractor(serviceCoordinator: serviceCoordinator),
            let indexedControllers = createIndexedControllers(
                localizationManager: localizationManager,
                serviceCoordinator: serviceCoordinator
            )
        else { return nil }

        let presenter = MainTabBarPresenter(localizationManager: LocalizationManager.shared)

        let view = MainTabBarViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        view.viewControllers = indexedControllers.map(\.1)

        let wireframe = MainTabBarWireframe(cardScreenNavigationFactory: CardScreenNavigationFactory())

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}

// MARK: Private

private extension MainTabBarViewFactory {
    static func createInteractor(serviceCoordinator: ServiceCoordinatorProtocol) -> MainTabBarInteractor? {
        let urlServiceFacade: URLHandlingServiceFacadeProtocol = URLHandlingServiceFacade.shared

        guard
            let secretImportService: SecretImportServiceProtocol = urlServiceFacade.findInternalService(),
            let screenOpenService: ScreenOpenServiceProtocol = urlServiceFacade.findInternalService(),
            let walletMigrateService: WalletMigrationServiceProtocol = urlServiceFacade.findInternalService(),
            let pushScreenOpenService = PushNotificationHandlingService.shared.service else {
            Logger.shared.error("Can't find required service")
            return nil
        }

        let securedLayer = SecurityLayerService.shared
        let inAppUpdatesService = InAppUpdatesServiceFactory().createService()

        let interactor = MainTabBarInteractor(
            eventCenter: EventCenter.shared,
            serviceCoordinator: serviceCoordinator,
            secretImportService: secretImportService,
            walletMigrationService: walletMigrateService,
            screenOpenService: screenOpenService,
            pushScreenOpenService: pushScreenOpenService,
            cloudBackupMediator: CloudBackupSyncMediatorFacade.sharedMediator,
            securedLayer: securedLayer,
            inAppUpdatesService: inAppUpdatesService,
            settingsManager: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        return interactor
    }

    static func createIndexedControllers(
        localizationManager: LocalizationManagerProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> [(Int, UIViewController)]? {
        let walletNotificationService = serviceCoordinator.walletNotificationService
        let delegatedAccountSyncService = serviceCoordinator.delegatedAccountSyncService

        guard
            let walletController = createWalletController(
                for: localizationManager,
                dappMediator: serviceCoordinator.dappMediator,
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
        dappMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        guard let viewController = AssetListViewFactory.createView(
            with: dappMediator,
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        )?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarAssetsTitle(preferredLanguages: locale.rLanguages)
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
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> UIViewController? {
        let viewController = StakingDashboardViewFactory.createView(
            walletNotificationService: walletNotificationService,
            delegatedAccountSyncService: delegatedAccountSyncService
        )?.controller ?? UIViewController()

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarStakingTitle(preferredLanguages: locale.rLanguages)
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
            R.string.localizable.tabbarSettingsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabSettings()
        let selectedIconImage = R.image.iconTabSettingsFilled()

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
            R.string.localizable.tabbarVoteTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabVote()
        let selectedIconImage = R.image.iconTabVoteFilled()

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
            R.string.localizable.tabbarDappsTitle_2_4_3(preferredLanguages: locale.rLanguages)
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
