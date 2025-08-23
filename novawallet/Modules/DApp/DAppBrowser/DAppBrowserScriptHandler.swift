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
        clearScript(for: viewModel?.name)
    }

    init(contentController: WKUserContentController, delegate: DAppBrowserScriptHandlerDelegate) {
        self.contentController = contentController
        self.delegate = delegate
    }
}

// MARK: Private

private extension DAppBrowserScriptHandler {
    func clearScript(for name: String?) {
        guard let name else { return }

        contentController.removeScriptMessageHandler(forName: name)
    }
}

// MARK: Internal

extension DAppBrowserScriptHandler {
    func bind(viewModel: DAppTransportModel) {
        clearScript(for: self.viewModel?.name)
        clearScript(for: viewModel.name)

        viewModel.handlerNames.forEach { clearScript(for: $0) }

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
}

// MARK: WKScriptMessageHandler

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
