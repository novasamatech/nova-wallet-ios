import UIKit
import SoraFoundation
import SoraKeystore
import CommonWallet

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    static let crowdloanIndex: Int = 1

    static func createView() -> MainTabBarViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared
            .findService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let serviceCoordinator = ServiceCoordinator.createDefault()

        let interactor = MainTabBarInteractor(
            eventCenter: EventCenter.shared,
            serviceCoordinator: serviceCoordinator,
            keystoreImportService: keystoreImportService
        )

        guard let walletController = createWalletController(for: localizationManager) else {
            return nil
        }

        guard let stakingController = createStakingController(for: localizationManager) else {
            return nil
        }

        guard let crowdloanController = createCrowdloanController(
            for: localizationManager,
            state: CrowdloanSharedState()
        ) else {
            return nil
        }

        guard let dappsController = createDappsController(for: localizationManager) else {
            return nil
        }

        guard let settingsController = createProfileController(for: localizationManager) else {
            return nil
        }

        let view = MainTabBarViewController()
        view.viewControllers = [
            walletController,
            crowdloanController,
            dappsController,
            stakingController,
            settingsController
        ]

        let presenter = MainTabBarPresenter()

        let wireframe = MainTabBarWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    static func reloadCrowdloanView(on view: MainTabBarViewProtocol) {
        let localizationManager = LocalizationManager.shared

        guard let crowdloanController = createCrowdloanController(
            for: localizationManager,
            state: CrowdloanSharedState()
        ) else {
            return
        }

        view.didReplaceView(for: crowdloanController, for: Self.crowdloanIndex)
    }

    static func createWalletController(
        for localizationManager: LocalizationManagerProtocol
    ) -> UIViewController? {
        guard let viewController = WalletListViewFactory.createView()?.controller else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarAssetsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let commonIconImage = R.image.iconTabWallet()
        let selectedIconImage = R.image.iconTabWalletFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorNovaBlue()!)?
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

        let navigationController = FearlessNavigationController(rootViewController: viewController)

        return navigationController
    }

    static func createStakingController(
        for localizationManager: LocalizationManagerProtocol
    ) -> UIViewController? {
        let viewController = StakingMainViewFactory.createView()?.controller ?? UIViewController()

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarStakingTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let commonIconImage = R.image.iconTabStaking()
        let selectedIconImage = R.image.iconTabStakingFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorNovaBlue()!)?
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

        let navigationController = FearlessNavigationController(rootViewController: viewController)

        return navigationController
    }

    static func createProfileController(
        for localizationManager: LocalizationManagerProtocol
    ) -> UIViewController? {
        guard let viewController = SettingsViewFactory.createView()?.controller else { return nil }

        let navigationController = FearlessNavigationController(rootViewController: viewController)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarSettingsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabSettings()
        let selectedIconImage = R.image.iconTabSettingsFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorNovaBlue()!)?
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

    static func createCrowdloanController(
        for localizationManager: LocalizationManagerProtocol,
        state: CrowdloanSharedState
    ) -> UIViewController? {
        guard let crowloanView = CrowdloanListViewFactory.createView(with: state) else {
            return nil
        }

        let navigationController = FearlessNavigationController(rootViewController: crowloanView.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarCrowdloanTitle_v190(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabCrowloan()
        let selectedIconImage = R.image.iconTabCrowloanFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorNovaBlue()!)?
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

    static func createDappsController(for localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        guard let dappsView = DAppListViewFactory.createView() else {
            return nil
        }

        let navigationController = FearlessNavigationController(rootViewController: dappsView.controller)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarDappsTitle_2_4_3(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        let commonIconImage = R.image.iconTabDApps()
        let selectedIconImage = R.image.iconTabDAppsFilled()

        let commonIcon = commonIconImage?.tinted(with: R.color.colorWhite()!)?
            .withRenderingMode(.alwaysOriginal)
        let selectedIcon = selectedIconImage?.tinted(with: R.color.colorNovaBlue()!)?
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
