import Foundation
import RobinHood

final class DAppPolkadotExtensionTransport {
    weak var delegate: DAppBrowserTransportDelegate?
    private(set) var dataSource: DAppBrowserStateDataSource?
    private(set) var state: DAppBrowserStateProtocol?
}

extension DAppPolkadotExtensionTransport: DAppBrowserStateMachineProtocol {
    func emit(nextState: DAppBrowserStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        nextState.setup(with: dataSource)
    }

    func emit(response: DAppScriptResponse, nextState: DAppBrowserStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        delegate?.dAppTransport(self, didReceiveResponse: response)

        nextState.setup(with: dataSource)
    }

    func emit(authRequest: DAppAuthRequest, nextState: DAppBrowserStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        delegate?.dAppTransport(self, didReceiveAuth: authRequest)

        nextState.setup(with: dataSource)
    }

    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: DAppBrowserStateProtocol
    ) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        delegate?.dAppTransport(self, didReceiveConfirmation: signingRequest, of: type)

        nextState.setup(with: dataSource)
    }

    func emit(error: Error, nextState: DAppBrowserStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        delegate?.dAppTransport(self, didReceive: error)

        nextState.setup(with: dataSource)
    }

    func popMessage() {
        delegate?.dAppTransportAsksPopMessage(self)
    }
}

extension DAppPolkadotExtensionTransport: DAppBrowserTransportProtocol {
    var name: String { DAppTransports.polkadotExtension }

    func createBridgeScriptOperation() -> BaseOperation<DAppBrowserScript> {
        ClosureOperation<DAppBrowserScript> {
            guard let url = R.file.nova_minJs.url() else {
                throw DAppBrowserInteractorError.scriptFileMissing
            }

            let content = try String(contentsOf: url)

            return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
        }
    }

    func createSubscriptionScript(for _: DAppBrowserStateDataSource) -> DAppBrowserScript? {
        let content =
            """
            window.addEventListener("message", ({ data, source }) => {
              // only allow messages from our window, by the loader
              if (source !== window) {
                return;
              }

              if (data.origin === "dapp-request") {
                window.webkit.messageHandlers.\(name).postMessage(data);
              }
            });
            """

        let script = DAppBrowserScript(content: content, insertionPoint: .atDocEnd)
        return script
    }

    func bringPhishingDetectedStateIfNeeded() -> Bool {
        guard let state = state else {
            return false
        }

        let isPhishingState = state as? DAppBrowserPhishingDetectedState

        if isPhishingState != nil {
            return false
        }

        self.state = DAppBrowserPhishingDetectedState(stateMachine: self)

        return true
    }

    func isIdle() -> Bool {
        state?.canHandleMessage() ?? false
    }

    func start(with dataSource: DAppBrowserStateDataSource) {
        self.dataSource = dataSource
        state = DAppBrowserWaitingAuthState(stateMachine: self)
    }

    func process(message: Any, host _: String) {
        guard
            let dict = message as? NSDictionary,
            let parsedMessage = try? dict.map(to: PolkadotExtensionMessage.self) else {
            delegate?.dAppTransport(self, didReceive: DAppBrowserInteractorError.unexpectedMessageType)
            return
        }

        guard let dataSource = dataSource else {
            return
        }

        state?.handle(message: parsedMessage, dataSource: dataSource)
    }

    func processConfirmation(response: DAppOperationResponse) {
        guard let dataSource = dataSource else {
            return
        }

        state?.handleOperation(response: response, dataSource: dataSource)
    }

    func processAuth(response: DAppAuthResponse) {
        guard let dataSource = dataSource else {
            return
        }

        state?.handleAuth(response: response, dataSource: dataSource)
    }

    func stop() {
        state?.stateMachine = nil
        state = nil
        dataSource = nil
    }
}
