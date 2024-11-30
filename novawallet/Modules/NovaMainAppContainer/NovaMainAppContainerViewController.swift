import UIKit

final class NovaMainAppContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = NovaMainAppContainerViewLayout

    let presenter: NovaMainAppContainerPresenterProtocol

    var tabBar: MainTabBarProtocol?
    var browserWidget: DAppBrowserWidgetProtocol?
    
    let logger: LoggerProtocol

    init(
        presenter: NovaMainAppContainerPresenterProtocol,
        logger: LoggerProtocol
    ) {
        self.presenter = presenter
        self.logger = logger

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
    func createTransitionLayoutDependencies(
        for state: DAppBrowserWidgetLayout
    ) -> DAppBrowserLayoutTransitionDependencies {
        switch state {
        case .closed: browserCloseLayoutDependencies()
        case .minimized: browserMinimizeLayoutDependencies()
        case .maximized: browserMaximizeLayoutDependencies()
        }
    }

    func browserCloseLayoutDependencies() -> DAppBrowserLayoutTransitionDependencies {
        DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview().inset(-84)
                }

                return self?.rootView
            },
            animatableClosure: { [weak self] in
                self?.tabBar?.view.layer.maskedCorners = []
            }
        )
    }

    func browserMinimizeLayoutDependencies() -> DAppBrowserLayoutTransitionDependencies {
        DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview()
                    make.height.equalTo(78)
                }

                return self?.rootView
            },
            animatableClosure: { [weak self] in
                self?.tabBar?.view.layer.maskedCorners = [
                    .layerMinXMaxYCorner,
                    .layerMaxXMaxYCorner
                ]
            }
        )
    }

    func browserMaximizeLayoutDependencies() -> DAppBrowserLayoutTransitionDependencies {
        let fullHeight = view.frame.size.height
        let safeAreaInsets = view.safeAreaInsets
        let totalHeight = fullHeight + safeAreaInsets.top + safeAreaInsets.bottom

        return DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview()
                    make.height.equalTo(totalHeight)
                }

                return self?.rootView
            }
        )
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
        makeTransition(
            for: state,
            using: transitionBuilder
        )
    }

    func makeTransition(
        for state: DAppBrowserWidgetState,
        using transitionBuilder: DAppBrowserWidgetTransitionBuilder?
    ) {
        let builder = if let transitionBuilder {
            transitionBuilder
        } else {
            DAppBrowserWidgetTransitionBuilder()
        }

        let widgetLayout = DAppBrowserWidgetLayout(from: state)
        let transitionDependencies = createTransitionLayoutDependencies(for: widgetLayout)

        builder.setWidgetLayout(transitionDependencies)

        do {
            let transition = try builder.build(for: widgetLayout)

            transition.start()
        } catch {
            logger.error("Failed to build transition: \(error)")
        }
    }
}

// MARK: NovaMainAppContainerViewProtocol

extension NovaMainAppContainerViewController: NovaMainAppContainerViewProtocol {
    func openBrowser(with tab: DAppBrowserTab?) {
        browserWidget?.openBrowser(with: tab)
    }
}
