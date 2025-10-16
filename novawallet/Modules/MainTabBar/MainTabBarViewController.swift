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

        configureTabBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }

        presenter.viewDidAppear()
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
