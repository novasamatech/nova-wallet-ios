import Foundation
import WebKit

protocol DAppBrowserScriptHandlerDelegate: AnyObject {
    func browserScriptHandler(_ handler: DAppBrowserScriptHandler, didReceive message: WKScriptMessage)
}

final class DAppBrowserScriptHandler: NSObject {
    weak var delegate: DAppBrowserScriptHandlerDelegate?
    let contentController: WKUserContentController

    private(set) var viewModel: DAppTransportModel?

    deinit {
        clearScript(for: viewModel)
    }

    init(contentController: WKUserContentController, delegate: DAppBrowserScriptHandlerDelegate) {
        self.contentController = contentController
        self.delegate = delegate
    }

    func bind(viewModel: DAppTransportModel) {
        self.viewModel = viewModel

        clearScript(for: viewModel)

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

        contentController.add(self, name: viewModel.name)
    }

    private func clearScript(for viewModel: DAppTransportModel?) {
        guard let viewModel else { return }

        contentController.removeScriptMessageHandler(forName: viewModel.name)
    }
}

extension DAppBrowserScriptHandler: WKScriptMessageHandler {
    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard viewModel?.name == message.name else {
            return
        }

        delegate?.browserScriptHandler(self, didReceive: message)
    }
}
