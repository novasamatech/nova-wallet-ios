import UIKit

final class NovaMainAppContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = NovaMainAppContainerViewLayout

    let presenter: NovaMainAppContainerPresenterProtocol

    var tabBar: MainTabBarProtocol?
    var browserWidget: DAppBrowserWidgetProtocol?

    init(presenter: NovaMainAppContainerPresenterProtocol) {
        self.presenter = presenter

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
    }
}

// MARK: Private

private extension NovaMainAppContainerViewController {
    func layoutBrowserWidget(for state: DAppBrowserWidgetLayout) {
        switch state {
        case .closed: animateBrowserWidgetClose()
        case .minimized: animateBrowserWidgetMinimized()
        case .maximized: animateBrowserWidgetMaximized()
        }
    }

    func animateBrowserWidgetClose() {
        browserWidget?.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview().inset(-84)
        }

        UIView.animate(withDuration: 0.3) {
            self.tabBar?.view.layer.maskedCorners = []
            self.rootView.layoutIfNeeded()
        }
    }

    func animateBrowserWidgetMinimized() {
        browserWidget?.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(78)
        }

        UIView.animate(withDuration: 0.3) {
            self.tabBar?.view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.rootView.layoutIfNeeded()
        }
    }

    func animateBrowserWidgetMaximized() {
        let fullHeight = view.frame.size.height
        let safeAreaInsets = view.safeAreaInsets
        let totalHeight = fullHeight + safeAreaInsets.top + safeAreaInsets.bottom

        browserWidget?.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(totalHeight)
        }

        UIView.animate(withDuration: 0.3) {
            self.rootView.layoutIfNeeded()
        }
    }
}

// MARK: Internal

extension NovaMainAppContainerViewController {
    func setupLayout(
        bottomView: UIView,
        topView: UIView
    ) {
        rootView.addSubview(bottomView)

        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(-84)
            make.height.equalTo(78)
        }

        rootView.addSubview(topView)

        topView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomView.snp.top).inset(-6)
        }

        topView.layer.cornerRadius = 16
        topView.layer.masksToBounds = true
    }
}

// MARK: DAppBrowserWidgetParentControllerProtocol

extension NovaMainAppContainerViewController: DAppBrowserWidgetParentControllerProtocol {
    func didReceiveWidgetState(_ state: DAppBrowserWidgetState) {
        let widgetLayout = DAppBrowserWidgetLayout(from: state)

        layoutBrowserWidget(for: widgetLayout)
    }
}

// MARK: NovaMainAppContainerViewProtocol

extension NovaMainAppContainerViewController: NovaMainAppContainerViewProtocol {
    func openBrowser(with tab: DAppBrowserTab?) {
        browserWidget?.openBrowser(with: tab)
    }
}
