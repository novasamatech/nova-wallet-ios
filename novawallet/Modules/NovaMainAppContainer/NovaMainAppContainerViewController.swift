import UIKit
import SnapKit

final class NovaMainAppContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = NovaMainAppContainerViewLayout

    let presenter: NovaMainAppContainerPresenterProtocol
    let logger: LoggerProtocol

    var tabBar: MainTabBarProtocol?
    var browserWidget: DAppBrowserWidgetProtocol?
    var topContainerBottomConstraint: NSLayoutConstraint?

    var topContainerBottomOffset: CGFloat {
        abs(topContainerBottomConstraint?.constant ?? 0)
    }

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
                    make.bottom.equalToSuperview().inset(-Constants.topContainerBottomOffset)
                    make.height.equalTo(Constants.minimizedWidgetHeight)
                }

                self?.topContainerBottomConstraint?.constant = 0

                return self?.rootView
            },
            animatableClosure: { [weak self] in
                self?.tabBar?.view.layer.maskedCorners = []
                self?.updateModalsLayoutIfNeeded()
            }
        )
    }

    func browserMinimizeLayoutDependencies() -> DAppBrowserLayoutTransitionDependencies {
        DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.bottom.equalToSuperview()
                    make.height.equalTo(Constants.minimizedWidgetHeight)
                }

                self?.topContainerBottomConstraint?.constant = -Constants.topContainerBottomOffset

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

        return DAppBrowserLayoutTransitionDependencies(
            layoutClosure: { [weak self] in
                self?.browserWidget?.view.snp.updateConstraints { make in
                    make.height.equalTo(fullHeight)
                    make.bottom.equalToSuperview()
                }

                self?.topContainerBottomConstraint?.constant = -Constants.topContainerBottomOffset

                return self?.rootView
            }
        )
    }

    func updateModalsLayoutIfNeeded() {
        var presentedViewController = tabBar?.presentedController()

        while presentedViewController != nil {
            let presentationController = (presentedViewController?.presentationController as? ModalCardPresentationController)
            presentationController?.updateLayout()
            presentedViewController = presentedViewController?.presentedViewController
        }
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
            make.leading.trailing.top.equalToSuperview()
        }

        topContainerBottomConstraint = topView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        topContainerBottomConstraint?.isActive = true

        topView.layer.cornerRadius = 16
        topView.layer.masksToBounds = true

        rootView.addSubview(bottomView)

        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(-Constants.topContainerBottomOffset)
            make.height.equalTo(Constants.minimizedWidgetHeight)
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
        static let topContainerBottomOffset: CGFloat = minimizedWidgetHeight + childSpacing
    }
}
