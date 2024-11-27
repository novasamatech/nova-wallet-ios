import UIKit

final class NovaMainAppContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = NovaMainAppContainerViewLayout

    let presenter: NovaMainAppContainerPresenterProtocol

    let tabController: UIViewController
    let browserWidgerController: NovaMainContainerDAppBrowserProtocol

    private var browserWidgetViewModel: DAppBrowserWidgetViewModel = .empty

    private var overlayWindow: UIWindow?

    init(
        presenter: NovaMainAppContainerPresenterProtocol,
        tabController: UIViewController,
        browserWidgerController: NovaMainContainerDAppBrowserProtocol
    ) {
        self.presenter = presenter
        self.tabController = tabController
        self.browserWidgerController = browserWidgerController

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

        presenter.setup()

        setupChildViewControllers()
        setupActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

private extension NovaMainAppContainerViewController {
    func setupChildViewControllers() {
        guard let tabController = tabController as? UITabBarController else {
            return
        }

        addChild(browserWidgerController.controller)
        rootView.addSubview(browserWidgerController.controller.view)

        browserWidgerController.controller.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(-84)
            make.height.equalTo(78)
        }
        browserWidgerController.controller.didMove(toParent: self)

        browserWidgerController.controller.view.isHidden = true

        addChild(tabController)
        rootView.addSubview(tabController.view)

        tabController.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(browserWidgerController.controller.view.snp.top).inset(-6)
        }

        tabController.view.layer.cornerRadius = 16
        tabController.view.layer.masksToBounds = true

        tabController.didMove(toParent: self)
    }

    func createBrowserWidgetWindow() -> UIWindow {
        let windowHeight: CGFloat = 78

        let frame = CGRect(
            x: 0,
            y: UIScreen.main.bounds.height - windowHeight,
            width: UIScreen.main.bounds.width,
            height: windowHeight
        )
        let window = UIWindow(frame: frame)
        window.windowLevel = .alert
        window.backgroundColor = .clear

        window.addSubview(rootView.browserVidgetView)

        rootView.browserVidgetView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.height.equalTo(78)
        }

        window.isHidden = false

        return window
    }

    func setupActions() {
        rootView.browserVidgetView.closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    func animateBrowserWidgetClose() {
        browserWidgerController.controller.view.isHidden = false
        overlayWindow = nil

        browserWidgerController.controller.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview().inset(-84)
        }

        UIView.animate(withDuration: 0.3) {
            self.tabController.view.layer.maskedCorners = []
            self.rootView.layoutIfNeeded()
        }
    }

    func animateBrowserWidgetShow() {
        overlayWindow = nil
        browserWidgerController.controller.view.isHidden = false

        browserWidgerController.controller.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
        }

        UIView.animate(withDuration: 0.3) {
            self.tabController.view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.rootView.layoutIfNeeded()
        } completion: { _ in
            self.overlayWindow = self.createBrowserWidgetWindow()
            self.browserWidgerController.controller.view.isHidden = true
        }
    }

    @objc func actionClose() {
        browserWidgerController.closeTabs()
    }
}

extension NovaMainAppContainerViewController: DAppBrowserWidgetParentControllerProtocol {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel) {
        guard self.browserWidgetViewModel != browserWidgetViewModel else {
            rootView.browserVidgetView.title.text = browserWidgetViewModel.title

            return
        }

        self.browserWidgetViewModel = browserWidgetViewModel

        rootView.browserVidgetView.title.text = browserWidgetViewModel.title

        switch browserWidgetViewModel {
        case .empty:
            animateBrowserWidgetClose()
        case .some:
            animateBrowserWidgetShow()
        }
    }
}

extension NovaMainAppContainerViewController: NovaMainAppContainerViewProtocol {}
