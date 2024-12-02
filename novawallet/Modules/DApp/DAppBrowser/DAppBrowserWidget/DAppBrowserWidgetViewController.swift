import UIKit

protocol DAppBrowserWidgetParentControllerProtocol: AnyObject {
    func didReceiveWidgetState(
        _ state: DAppBrowserWidgetState,
        transitionBuilder: DAppBrowserWidgetTransitionBuilder?
    )
}

final class DAppBrowserWidgetViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserWidgetViewLayout

    var state: DAppBrowserWidgetState?

    var parentController: DAppBrowserWidgetParentControllerProtocol? {
        parent as? DAppBrowserWidgetParentControllerProtocol
    }

    let presenter: DAppBrowserWidgetPresenterProtocol

    init(presenter: DAppBrowserWidgetPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppBrowserWidgetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupActions()
    }
}

// MARK: Private

private extension DAppBrowserWidgetViewController {
    func setupActions() {
        rootView.browserWidgetView.closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )

        rootView.browserWidgetView.contentContainerView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(actionTap)
            )
        )
    }

    @objc func actionClose() {
        presenter.closeTabs()
    }

    @objc func actionTap() {
        let transitionBuilder = createTransitionBuilder()
        presenter.showBrowser(transitionBuilder: transitionBuilder)
    }
}

// MARK: DAppBrowserWidgetViewProtocol

extension DAppBrowserWidgetViewController: DAppBrowserWidgetViewProtocol {
    func didReceive(_ browserWidgetModel: DAppBrowserWidgetModel) {
        rootView.browserWidgetView.title.text = browserWidgetModel.title

        guard state != browserWidgetModel.widgetState else { return }

        state = browserWidgetModel.widgetState

        parentController?.didReceiveWidgetState(
            browserWidgetModel.widgetState,
            transitionBuilder: browserWidgetModel.transitionBuilder
        )
    }

    func createTransitionBuilder() -> DAppBrowserWidgetTransitionBuilder {
        DAppBrowserWidgetTransitionBuilder()
            .setBrowserView(
                { [weak self] in self?.children.first?.view }
            )
            .setWidgetContentView(
                { [weak self] in self?.rootView.browserWidgetView }
            )
    }
}

// MARK: DAppBrowserWidgetProtocol

extension DAppBrowserWidgetViewController: DAppBrowserWidgetProtocol {
    func openBrowser(with tab: DAppBrowserTab?) {
        let transitionBuilder = createTransitionBuilder()

        presenter.showBrowser(
            with: tab,
            transitionBuilder: transitionBuilder
        )
    }
}

// MARK: DAppBrowserParentViewProtocol

extension DAppBrowserWidgetViewController: DAppBrowserParentViewProtocol {
    func close() {
        let transitionBuilder = createTransitionBuilder()

        presenter.actionDone(
            transitionBuilder: transitionBuilder
        )
    }

    func minimize() {
        let transitionBuilder = createTransitionBuilder()

        presenter.minimizeBrowser(
            transitionBuilder: transitionBuilder
        )
    }
}

// MARK: DAppBrowserWidgetState

enum DAppBrowserWidgetState {
    case disabled
    case closed
    case miniature
    case fullBrowser
}
