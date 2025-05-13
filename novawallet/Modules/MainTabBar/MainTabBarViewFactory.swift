import UIKit
import Foundation_iOS
import Keystore_iOS

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static func createView() -> MainTabBarViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let serviceCoordinator = ServiceCoordinator.createDefault(for: URLHandlingService.shared)

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

        let wireframe = MainTabBarWireframe()

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
        guard
            let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared
            .findService(),
            let screenOpenService: ScreenOpenServiceProtocol = URLHandlingService.shared.findService(),
            let pushScreenOpenService = PushNotificationHandlingService.shared.service
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let securedLayer = SecurityLayerService.shared
        let inAppUpdatesService = InAppUpdatesServiceFactory().createService()

        let interactor = MainTabBarInteractor(
            eventCenter: EventCenter.shared,
            serviceCoordinator: serviceCoordinator,
            keystoreImportService: keystoreImportService,
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
        guard
            let assetsController = createAssetsController(
                for: localizationManager,
                serviceCoordinator: serviceCoordinator
            ),
            let stakingController = createStakingController(
                for: localizationManager,
                serviceCoordinator: serviceCoordinator
            ),
            let payController = createPayController(for: localizationManager),
            let voteController = createVoteController(
                for: localizationManager,
                serviceCoordinator: serviceCoordinator
            ),
            let dappsController = createDappsController(
                for: localizationManager,
                serviceCoordinator: serviceCoordinator
            )
        else {
            return nil
        }

        return [
            (MainTabBarIndex.assets, assetsController),
            (MainTabBarIndex.vote, voteController),
            (MainTabBarIndex.pay, payController),
            (MainTabBarIndex.staking, stakingController),
            (MainTabBarIndex.dapps, dappsController)
        ].sorted { cont1, cont2 in
            cont1.0 < cont2.0
        }
    }

    static func createAssetsController(
        for localizationManager: LocalizationManagerProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> UIViewController? {
        guard
            let assetsView = AssetListViewFactory.createView(),
            let rootView = NavigationRootViewFactory.createView(
                with: assetsView,
                serviceCoordinator: serviceCoordinator
            ) else {
            return nil
        }

        let viewController = rootView.controller

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
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> UIViewController? {
        guard
            let stakingView = StakingDashboardViewFactory.createView(for: serviceCoordinator),
            let rootView = NavigationRootViewFactory.createView(
                with: stakingView,
                serviceCoordinator: serviceCoordinator
            ) else {
            return nil
        }

        let viewController = rootView.controller

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

    static func createVoteController(
        for localizationManager: LocalizationManagerProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> UIViewController? {
        guard
            let voteView = VoteViewFactory.createView(),
            let rootView = NavigationRootViewFactory.createView(
                with: voteView,
                serviceCoordinator: serviceCoordinator
            ) else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: rootView.controller)

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
        serviceCoordinator: ServiceCoordinatorProtocol
    ) -> UIViewController? {
        guard
            let dappsView = DAppListViewFactory.createView(),
            let rootView = NavigationRootViewFactory.createView(
                with: dappsView,
                serviceCoordinator: serviceCoordinator
            ) else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: rootView.controller)

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

    static func createPayController(for localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        guard let payView = PayRootViewFactory.createView() else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: payView.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarPayTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabPay()
        let selectedIconImage = R.image.iconTabPayFilled()

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
