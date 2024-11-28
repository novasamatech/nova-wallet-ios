import UIKit

protocol DAppBrowserWidgetParentControllerProtocol: AnyObject {
    func didReceiveWidgetState(_ state: DAppBrowserWidgetState)
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

        rootView.browserWidgetView.backgroundView.addGestureRecognizer(
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
        presenter.showBrowser()
    }
}

// MARK: DAppBrowserWidgetViewProtocol

extension DAppBrowserWidgetViewController: DAppBrowserWidgetViewProtocol {
    func didReceive(_ browserWidgetModel: DAppBrowserWidgetModel) {
        rootView.browserWidgetView.title.text = title

        guard state != browserWidgetModel.widgetState else { return }

        state = browserWidgetModel.widgetState

        parentController?.didReceiveWidgetState(browserWidgetModel.widgetState)
    }
}

// MARK: DAppBrowserWidgetProtocol

extension DAppBrowserWidgetViewController: DAppBrowserWidgetProtocol {
    func openBrowser(with tab: DAppBrowserTab?) {
        presenter.showBrowser(with: tab)
    }
}

// MARK: DAppBrowserParentViewProtocol

extension DAppBrowserWidgetViewController: DAppBrowserParentViewProtocol {
    func close() {
        presenter.actionDone()
    }
}

// MARK: DAppBrowserWidgetState

enum DAppBrowserWidgetState {
    case disabled
    case closed
    case miniature
    case fullBrowser
}
