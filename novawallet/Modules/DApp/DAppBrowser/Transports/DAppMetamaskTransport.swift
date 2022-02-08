import Foundation
import RobinHood

final class DAppMetamaskTransport {
    static let subscriptionName = "_metamask_"

    weak var delegate: DAppBrowserTransportDelegate?
    let isDebug: Bool

    init(isDebug: Bool) {
        self.isDebug = isDebug
    }
}

extension DAppMetamaskTransport: DAppBrowserTransportProtocol {
    var name: String { DAppTransports.metamask }

    func createBridgeScriptOperation() -> BaseOperation<DAppBrowserScript> {
        ClosureOperation<DAppBrowserScript> {
            guard let url = R.file.metamaskMinJs.url() else {
                throw DAppBrowserInteractorError.scriptFileMissing
            }

            let content = try String(contentsOf: url)

            return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
        }
    }

    func createSubscriptionScript() -> DAppBrowserScript {
        let content =
            """
            (function() {
                var config = {
                    isDebug: \(isDebug)
                };
                window.ethereum = new trustwallet.Provider(config);
                window.web3 = new trustwallet.Web3(window.ethereum);
                trustwallet.postMessage = (jsonString) => {
                    webkit.messageHandlers.\(Self.subscriptionName).postMessage(jsonString)
                };
            })();
            """

        let script = DAppBrowserScript(content: content, insertionPoint: .atDocEnd)
        return script
    }

    func isIdle() -> Bool {
        true
    }

    func start(with _: DAppBrowserStateDataSource) {}
    func process(message _: Any) {}
    func processConfirmation(response _: DAppOperationResponse) {}
    func processAuth(response _: DAppAuthResponse) {}
    func stop() {}
}
