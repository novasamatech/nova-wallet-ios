import UIKit

protocol BrowserWidgetViewParentControllerProtocol: AnyObject {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel)
}

final class BrowserWidgetViewController: UIViewController, ViewHolder {
    typealias RootViewType = BrowserWidgetViewLayout

    var parentController: BrowserWidgetViewParentControllerProtocol? {
        parent as? BrowserWidgetViewParentControllerProtocol
    }

    let presenter: BrowserWidgetPresenterProtocol

    init(presenter: BrowserWidgetPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BrowserWidgetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupActions()
    }

    private func setupActions() {
        rootView.browserVidgetView.closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    @objc private func actionClose() {
        presenter.closeTabs()
    }
}

extension BrowserWidgetViewController: BrowserWidgetViewProtocol {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel) {
        if let title {
            rootView.browserVidgetView.title.text = title
        }

        parentController?.didReceive(browserWidgetViewModel)
    }
}

extension BrowserWidgetViewController: NovaMainContainerDAppBrowserProtocol {
    func closeTabs() {
        presenter.closeTabs()
    }
}
