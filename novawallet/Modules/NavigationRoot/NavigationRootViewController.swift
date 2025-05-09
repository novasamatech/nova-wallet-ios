import UIKit

final class NavigationRootViewController: DecorateNavbarOnScrollController {
    typealias RootViewType = NavigationRootViewLayout

    let presenter: NavigationRootPresenterProtocol

    init(scrollHost: ScrollViewHostControlling, presenter: NavigationRootPresenterProtocol) {
        self.presenter = presenter

        super.init(scrollHost: scrollHost)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NavigationRootViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NavigationRootViewController: NavigationRootViewProtocol {}
