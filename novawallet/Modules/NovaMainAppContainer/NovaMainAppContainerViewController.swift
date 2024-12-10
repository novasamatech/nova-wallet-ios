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

                self?.tabBar?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview()
                }

                return self?.rootView
            },
            animatableClosure: { [weak self] in
                self?.tabBar?.view.layer.maskedCorners = []
            }
        )
    }

    func browserMinimizeLayoutDependencies() -> DAppBrowserLayoutTransitionDependencies {
        let tabBarHeightInset = Constants.minimizedWidgetHeight + Constants.childSpacing

        return DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.height.equalTo(78)
                }

                self?.tabBar?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview().inset(84)
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
        let tabBarTopOffset = fullHeight - Constants.minimizedWidgetHeight - Constants.childSpacing

        return DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.height.equalTo(fullHeight)
                    make.bottom.equalToSuperview()
                }

                self?.tabBar?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview().inset(84)
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
        rootView.addSubview(topView)

        topView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }

        topView.layer.cornerRadius = 16
        topView.layer.masksToBounds = true

        rootView.addSubview(bottomView)

        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(-84)
            make.height.equalTo(78)
        }
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

// MARK: Constants

private extension NovaMainAppContainerViewController {
    enum Constants {
        static let minimizedWidgetHeight: CGFloat = 78
        static let childSpacing: CGFloat = 6
    }
}

extension UIViewController {
    func setTabBarHidden(_ hidden: Bool, animated: Bool = true, duration: TimeInterval = 0.25) {
        if tabBarController?.tabBar.isHidden != hidden {
            if animated {
                // Show the tabbar before the animation in case it has to appear
                if (tabBarController?.tabBar.isHidden)! {
                    tabBarController?.tabBar.isHidden = hidden
                }
                if let frame = tabBarController?.tabBar.frame {
                    let factor: CGFloat = hidden ? 1 : -1
                    let yPoint = frame.origin.y + (frame.size.height * factor)
                    UIView.animate(withDuration: duration, animations: {
                        self.tabBarController?.tabBar.frame = CGRect(x: frame.origin.x, y: yPoint, width: frame.width, height: frame.height)
                    }) { _ in
                        // hide the tabbar after the animation in case ti has to be hidden
                        if !(self.tabBarController?.tabBar.isHidden)! {
                            self.tabBarController?.tabBar.isHidden = hidden
                        }
                    }
                }
            }
        }
    }
}
