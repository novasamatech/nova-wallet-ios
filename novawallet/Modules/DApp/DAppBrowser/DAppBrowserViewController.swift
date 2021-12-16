import UIKit
import WebKit

final class DAppBrowserViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserViewLayout

    let presenter: DAppBrowserPresenterProtocol

    private var viewModel: DAppBrowserModel?

    init(presenter: DAppBrowserPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppBrowserViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DAppBrowserViewController: WKScriptMessageHandler {
    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard viewModel?.subscriptionName == message.name else {
            return
        }

        presenter.process(message: message.body)
    }
}

extension DAppBrowserViewController: DAppBrowserViewProtocol {
    func didReceive(viewModel: DAppBrowserModel) {
        let contentController = rootView.webView.configuration.userContentController

        if let oldViewModel = self.viewModel {
            contentController.removeAllUserScripts()
            contentController.removeScriptMessageHandler(forName: oldViewModel.subscriptionName)
        }

        self.viewModel = viewModel

        for script in viewModel.scripts {
            let wkScript: WKUserScript
            switch script.insertionPoint {
            case .atDocStart:
                wkScript = WKUserScript(
                    source: script.content,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            case .atDocEnd:
                wkScript = WKUserScript(
                    source: script.content,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: false
                )
            }

            contentController.addUserScript(wkScript)
        }

        contentController.add(self, name: viewModel.subscriptionName)

        let request = URLRequest(url: viewModel.url)
        rootView.webView.load(request)
    }
}
