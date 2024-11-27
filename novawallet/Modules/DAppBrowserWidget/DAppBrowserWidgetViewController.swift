import UIKit

protocol DAppBrowserWidgetParentControllerProtocol: AnyObject {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel)
    func openBrowser()
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
        parentController?.openBrowser()
    }
}

// MARK: DAppBrowserWidgetViewProtocol

extension DAppBrowserWidgetViewController: DAppBrowserWidgetViewProtocol {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel) {
        if let title = browserWidgetViewModel.title {
            rootView.browserWidgetView.title.text = title
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
