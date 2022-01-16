import UIKit

final class MainTabBarViewController: UITabBarController {
    var presenter: MainTabBarPresenterProtocol!

    private var viewAppeared: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self

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
            NSAttributedString.Key.foregroundColor: R.color.colorWhite48()!,
            NSAttributedString.Key.font: UIFont.caption2
        ]
        let selectedAttributes = [
            NSAttributedString.Key.foregroundColor: R.color.colorNovaBlue()!,
            NSAttributedString.Key.font: UIFont.caption2
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.backgroundEffect = UIBlurEffect(style: .dark)

        tabBar.standardAppearance = appearance

        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

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

extension MainTabBarViewController: MainTabBarViewProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        setViewControllers(newViewControllers, animated: false)
    }
}
