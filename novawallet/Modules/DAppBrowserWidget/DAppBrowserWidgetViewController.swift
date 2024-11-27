import UIKit

protocol DAppBrowserWidgetParentControllerProtocol: AnyObject {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel)
}

final class DAppBrowserWidgetViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserWidgetViewLayout

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
        rootView.browserVidgetView.closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    @objc func actionClose() {
        presenter.closeTabs()
    }
}

// MARK: DAppBrowserWidgetViewProtocol

extension DAppBrowserWidgetViewController: DAppBrowserWidgetViewProtocol {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel) {
        if let title {
            rootView.browserVidgetView.title.text = title
        }

        parentController?.didReceive(browserWidgetViewModel)
    }
}

// MARK: NovaMainContainerDAppBrowserProtocol

extension DAppBrowserWidgetViewController: NovaMainContainerDAppBrowserProtocol {
    func closeTabs() {
        presenter.closeTabs()
    }
}
