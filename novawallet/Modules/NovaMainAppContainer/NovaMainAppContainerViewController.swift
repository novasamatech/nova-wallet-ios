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
    func layoutBrowserWidget(
        for state: DAppBrowserWidgetLayout,
        _ completion: (() -> Void)?
    ) {
        switch state {
        case .closed: animateBrowserWidgetClose(completion)
        case .minimized: animateBrowserWidgetMinimized(completion)
        case .maximized: animateBrowserWidgetMaximized(completion)
        }
    }

    func animateBrowserWidgetClose(_ completion: (() -> Void)?) {
        browserWidget?.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview().inset(-84)
        }

        UIView.animate(withDuration: 0.3) {
            self.tabBar?.view.layer.maskedCorners = []
            self.rootView.layoutIfNeeded()
        } completion: { _ in completion?() }
    }

    func animateBrowserWidgetMinimized(_ completion: (() -> Void)?) {
        browserWidget?.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(78)
        }

        UIView.animate(withDuration: 0.3) {
            self.tabBar?.view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.rootView.layoutIfNeeded()
        } completion: { _ in completion?() }
    }

    func animateBrowserWidgetMaximized(_ completion: (() -> Void)?) {
        let fullHeight = view.frame.size.height
        let safeAreaInsets = view.safeAreaInsets
        let totalHeight = fullHeight + safeAreaInsets.top + safeAreaInsets.bottom

        browserWidget?.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalTo(totalHeight)
        }

        UIView.animate(withDuration: 0.3) {
            self.rootView.layoutIfNeeded()
        } completion: { _ in completion?() }
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
    func didReceiveWidgetState(
        _ state: DAppBrowserWidgetState,
        transitionBuilder: DAppBrowserWidgetTransitionBuilder?
    ) {
        guard let transitionBuilder else { return }

        makeTransition(
            for: state,
            using: transitionBuilder
        )
    }

    func makeTransition(
        for state: DAppBrowserWidgetState,
        using transitionBuilder: DAppBrowserWidgetTransitionBuilder
    ) {
        let widgetLayout = DAppBrowserWidgetLayout(from: state)

        do {
            let transition = try transitionBuilder.addingWidgetLayoutClosure { [weak self] completion in
                self?.layoutBrowserWidget(
                    for: widgetLayout,
                    completion
                )
            }.build(for: widgetLayout)

            transition.start()
        } catch {
            print(error)
        }
    }
}

// MARK: NovaMainAppContainerViewProtocol

extension NovaMainAppContainerViewController: NovaMainAppContainerViewProtocol {
    func openBrowser(with tab: DAppBrowserTab?) {
        browserWidget?.openBrowser(with: tab)
    }
}
