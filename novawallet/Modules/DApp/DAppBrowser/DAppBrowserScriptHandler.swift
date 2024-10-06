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
        clearScript()
    }

    init(contentController: WKUserContentController, delegate: DAppBrowserScriptHandlerDelegate) {
        self.contentController = contentController
        self.delegate = delegate
    }

    func bind(viewModel: DAppTransportModel) {
        clearScript()

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

        viewModel.handlerNames.forEach { handlerName in
            contentController.add(self, name: handlerName)
        }
    }

    private func clearScript() {
        if let oldViewModel = viewModel {
            oldViewModel.handlerNames.forEach { handler in
                contentController.removeScriptMessageHandler(forName: handler)
            }
        }
    }
}

extension DAppBrowserScriptHandler: WKScriptMessageHandler {
    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let viewModel, viewModel.handlerNames.contains(message.name) else {
            return
        }

        delegate?.browserScriptHandler(self, didReceive: message)
    }
}
