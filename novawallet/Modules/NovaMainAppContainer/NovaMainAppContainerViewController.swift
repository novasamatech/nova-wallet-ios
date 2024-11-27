import UIKit

final class NovaMainAppContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = NovaMainAppContainerViewLayout

    let presenter: NovaMainAppContainerPresenterProtocol

    let tabController: UIViewController
    let browserWidgetController: NovaMainContainerDAppBrowserProtocol

    private var browserWidgetViewModel: DAppBrowserWidgetViewModel = .empty

    init(
        presenter: NovaMainAppContainerPresenterProtocol,
        tabController: UIViewController,
        browserWidgetController: NovaMainContainerDAppBrowserProtocol
    ) {
        self.presenter = presenter
        self.tabController = tabController
        self.browserWidgetController = browserWidgetController

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NovaMainAppContainerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupChildViewControllers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

// MARK: Private

private extension NovaMainAppContainerViewController {
    func setupChildViewControllers() {
        guard let tabController = tabController as? UITabBarController else {
            return
        }

        addChild(browserWidgetController.controller)
        rootView.addSubview(browserWidgetController.controller.view)

        browserWidgetController.controller.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(-84)
            make.height.equalTo(78)
        }
        browserWidgetController.controller.didMove(toParent: self)

        addChild(tabController)
        rootView.addSubview(tabController.view)

        tabController.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(browserWidgetController.controller.view.snp.top).inset(-6)
        }

        tabController.view.layer.cornerRadius = 16
        tabController.view.layer.masksToBounds = true

        tabController.didMove(toParent: self)
    }

    func animateBrowserWidgetClose() {
        browserWidgetController.controller.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview().inset(-84)
        }

        UIView.animate(withDuration: 0.3) {
            self.tabController.view.layer.maskedCorners = []
            self.rootView.layoutIfNeeded()
        }
    }

    func animateBrowserWidgetShow() {
        browserWidgetController.controller.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
        }

        UIView.animate(withDuration: 0.3) {
            self.tabController.view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.rootView.layoutIfNeeded()
        }
    }
}

// MARK: DAppBrowserWidgetParentControllerProtocol

extension NovaMainAppContainerViewController: DAppBrowserWidgetParentControllerProtocol {
    func openBrowser() {
        guard case let .some(_, tabsCount) = browserWidgetViewModel else {
            return
        }

        presenter.openBrowser(tabsCount: tabsCount)
    }

    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel) {
        guard self.browserWidgetViewModel != browserWidgetViewModel else {
            return
        }

        self.browserWidgetViewModel = browserWidgetViewModel

        switch browserWidgetViewModel {
        case .empty:
            animateBrowserWidgetClose()
        case .some:
            animateBrowserWidgetShow()
        }
    }
}

// MARK: NovaMainAppContainerViewProtocol

extension NovaMainAppContainerViewController: NovaMainAppContainerViewProtocol {}
