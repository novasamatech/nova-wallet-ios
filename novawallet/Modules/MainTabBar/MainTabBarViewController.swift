import UIKit
import Foundation_iOS

final class MainTabBarViewController: UITabBarController {
    let presenter: MainTabBarPresenterProtocol

    private var viewAppeared: Bool = false

    private let sharedStatusBarPresenter = SharedStatusPresenter()

    var syncStatus: SharedSyncStatus = .disabled

    init(
        presenter: MainTabBarPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self

        definesPresentationContext = true
        sharedStatusBarPresenter.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            configureNewYearTabBar()
            presenter.setup()
        }

        presenter.viewDidAppear()
    }

    private func configureNewYearTabBar() {
        let appearance = UITabBarAppearance()

        appearance.shadowImage = UIImage()
        appearance.backgroundEffect = UIBlurEffect(style: .dark)

        guard let items = tabBar.items else { return }

        let colors: [UIColor] = [
            R.color.colorTabNewYearAssets()!,
            R.color.colorTabNewYearVote()!,
            R.color.colorTabNewYearBrowser()!,
            R.color.colorTabNewYearStaking()!,
            R.color.colorTabNewYearSettings()!
        ]

        items.enumerated().forEach { index, item in
            congifureTabBarItem(item, with: colors[index])
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()

        appearance.shadowImage = UIImage()

        let normalAttributes = [
            NSAttributedString.Key.foregroundColor: R.color.colorIconNavbarInactive()!,
            NSAttributedString.Key.font: UIFont.caption2
        ]
        let selectedAttributes = [
            NSAttributedString.Key.foregroundColor: R.color.colorIconAccent()!,
            NSAttributedString.Key.font: UIFont.caption2
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.backgroundEffect = UIBlurEffect(style: .dark)

        tabBar.standardAppearance = appearance

        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    func congifureTabBarItem(
        _ item: UITabBarItem,
        with selectedColor: UIColor
    ) {
        let appearance = UITabBarAppearance()
        let itemAppearance = UITabBarItemAppearance()

        appearance.shadowImage = UIImage()

        itemAppearance.normal.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: R.color.colorIconNavbarInactive()!,
            NSAttributedString.Key.font: UIFont.caption2
        ]
        itemAppearance.selected.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: selectedColor,
            NSAttributedString.Key.font: UIFont.caption2
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        item.standardAppearance = appearance
        item.scrollEdgeAppearance = appearance
    }
}

// MARK: UITabBarControllerDelegate

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(
        _: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if viewController == viewControllers?[selectedIndex],
           let scrollableController = viewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }

        return true
    }
}

// MARK: MainTabBarViewProtocol

extension MainTabBarViewController: MainTabBarViewProtocol {
    func presentedController() -> UIViewController? {
        if let presentedViewController {
            return presentedViewController
        } else {
            let topViewControllers: [UIViewController]? = viewControllers?.compactMap {
                ($0 as? UINavigationController)?.topViewController
            }

            return topViewControllers?
                .filter { $0.presentedViewController != nil }
                .first?
                .presentedViewController
        }
    }

    func topViewController() -> UIViewController? {
        let navigationController = selectedViewController as? UINavigationController

        let topController = if let presentedViewController {
            presentedViewController
        } else if let topModalViewController = navigationController?.topModalViewController {
            topModalViewController
        } else if let topViewController = navigationController?.topViewController {
            topViewController
        } else {
            navigationController?.viewControllers.first
        }

        return topController
    }

    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        setViewControllers(newViewControllers, animated: false)
    }

    func setSyncStatus(_ syncStatus: SharedSyncStatus) {
        let wasSyncing = self.syncStatus == .syncing
        self.syncStatus = syncStatus

        switch syncStatus {
        case .disabled:
            sharedStatusBarPresenter.hide()
        case .syncing:
            sharedStatusBarPresenter.showPending(
                for: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonStatusBackupSyncing(),
                on: view
            )
        case .synced:
            if wasSyncing {
                sharedStatusBarPresenter.complete(
                    with: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.commonStatusBackupSynced()
                )
            }
        }
    }
}

// MARK: SharedStatusPresenterDelegate

extension MainTabBarViewController: SharedStatusPresenterDelegate {
    func didTapSharedStatusView() {
        presenter.activateStatusAction()
    }
}

// MARK: RootFlowStatusAlertPresenter

extension MainTabBarViewController: RootFlowStatusAlertPresenter {
    func presentStatusAlert(_ closure: FlowStatusPresentingClosure) {
        presenter.presentStatusAlert(closure)
    }
}

// MARK: Localizable

extension MainTabBarViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            switch syncStatus {
            case .disabled, .synced:
                break
            case .syncing:
                sharedStatusBarPresenter.showPending(
                    for: R.string(
                        preferredLanguages: selectedLocale.rLanguages
                    ).localizable.commonStatusBackupSyncing(),
                    on: view
                )
            }
        }
    }
}
