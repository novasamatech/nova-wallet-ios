import UIKit
import SoraFoundation
import SoraKeystore

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1

    static func createView() -> MainTabBarViewProtocol? {
        guard
            let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared
            .findService(),
            let screenOpenService: ScreenOpenServiceProtocol = URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let securedLayer = SecurityLayerService.shared

        let serviceCoordinator = ServiceCoordinator.createDefault(for: URLHandlingService.shared)
        let inAppUpdatesService = InAppUpdatesServiceFactory().createService()

        let interactor = MainTabBarInteractor(
            eventCenter: EventCenter.shared,
            serviceCoordinator: serviceCoordinator,
            keystoreImportService: keystoreImportService,
            screenOpenService: screenOpenService,
            securedLayer: securedLayer,
            inAppUpdatesService: inAppUpdatesService
        )

        let walletNotificationService = serviceCoordinator.walletNotificationService
        let proxySyncService = serviceCoordinator.proxySyncService

        guard let walletController = createWalletController(
            for: localizationManager,
            dappMediator: serviceCoordinator.dappMediator,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
        ) else {
            return nil
        }

        guard let stakingController = createStakingController(
            for: localizationManager,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
        ) else {
            return nil
        }

        guard let voteController = createVoteController(
            for: localizationManager,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
        ) else {
            return nil
        }

        guard let dappsController = createDappsController(
            for: localizationManager,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
        ) else {
            return nil
        }

        guard let settingsController = createProfileController(
            for: localizationManager,
            dappMediator: serviceCoordinator.dappMediator,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
        ) else {
            return nil
        }

        let indexedControllers: [(Int, UIViewController)] = [
            (MainTabBarIndex.wallet, walletController),
            (MainTabBarIndex.vote, voteController),
            (MainTabBarIndex.dapps, dappsController),
            (MainTabBarIndex.staking, stakingController),
            (MainTabBarIndex.settings, settingsController)
        ].sorted { cont1, cont2 in
            cont1.0 < cont2.0
        }

        let view = MainTabBarViewController()
        view.viewControllers = indexedControllers.map(\.1)

        let presenter = MainTabBarPresenter(localizationManager: LocalizationManager.shared)

        let wireframe = MainTabBarWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    static func createWalletController(
        for localizationManager: LocalizationManagerProtocol,
        dappMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        proxySyncService: ProxySyncServiceProtocol
    ) -> UIViewController? {
        guard let viewController = AssetListViewFactory.createView(
            with: dappMediator,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
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
        proxySyncService: ProxySyncServiceProtocol
    ) -> UIViewController? {
        let viewController = StakingDashboardViewFactory.createView(
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
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
        dappMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        proxySyncService: ProxySyncServiceProtocol
    ) -> UIViewController? {
        guard let view = SettingsViewFactory.createView(
            with: dappMediator,
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
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
        proxySyncService: ProxySyncServiceProtocol
    ) -> UIViewController? {
        guard let view = VoteViewFactory.createView(
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
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
        proxySyncService: ProxySyncServiceProtocol
    ) -> UIViewController? {
        guard let dappsView = DAppListViewFactory.createView(
            walletNotificationService: walletNotificationService,
            proxySyncService: proxySyncService
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
