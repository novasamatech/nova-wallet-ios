import Foundation
import RobinHood
import SubstrateSdk

final class DAppMetamaskTransport {
    static let subscriptionName = "_metamask_"

    weak var delegate: DAppBrowserTransportDelegate?
    private(set) var dataSource: DAppBrowserStateDataSource?
    private(set) var state: DAppMetamaskStateProtocol?
    private(set) var chain: MetamaskChain?

    let isDebug: Bool

    init(isDebug: Bool) {
        self.isDebug = isDebug
    }

    private func createConfirmationRequest(
        messageId: MetamaskMessage.Id,
        from signingOperation: JSON
    ) -> DAppOperationRequest? {
        guard let dataSource = dataSource else {
            return nil
        }

        return DAppOperationRequest(
            transportName: DAppTransports.metamask,
            identifier: "\(messageId)",
            wallet: dataSource.wallet,
            dApp: dataSource.dApp?.name ?? "",
            dAppIcon: dataSource.dApp?.icon,
            operationData: signingOperation
        )
    }
}

extension DAppMetamaskTransport: DAppMetamaskStateMachineProtocol {
    func emit(nextState: DAppMetamaskStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        nextState.setup(with: dataSource)
    }

    func emit(response: PolkadotExtensionResponse, nextState: DAppMetamaskStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        delegate?.dAppTransport(self, didReceiveResponse: response)

        nextState.setup(with: dataSource)
    }

    func emit(authRequest: DAppAuthRequest, nextState: DAppMetamaskStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        delegate?.dAppTransport(self, didReceiveAuth: authRequest)

        nextState.setup(with: dataSource)
    }

    func emit(
        messageId: MetamaskMessage.Id,
        signingOperation: JSON,
        nextState: DAppMetamaskStateProtocol
    ) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        if
            let request = createConfirmationRequest(messageId: messageId, from: signingOperation),
            let chain = chain {
            let type = DAppSigningType.ethereumTransaction(chain: chain)
            delegate?.dAppTransport(self, didReceiveConfirmation: request, of: type)
        } else {
            let error = DAppBrowserStateError.unexpected(reason: "Can't create signing request")
            delegate?.dAppTransport(self, didReceive: error)
        }

        nextState.setup(with: dataSource)
    }

    func emit(
        chain: MetamaskChain,
        postExecutionScript: PolkadotExtensionResponse,
        nextState: DAppMetamaskStateProtocol
    ) {
        guard let dataSource = dataSource else {
            return
        }

        self.chain = chain

        delegate?.dAppAskReload(self, postExecutionScript: postExecutionScript)

        nextState.setup(with: dataSource)
    }

    func emit(error: Error, nextState: DAppMetamaskStateProtocol) {
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

    func createSubscriptionScript(for dataSource: DAppBrowserStateDataSource) -> DAppBrowserScript? {
        guard let selectedAddress = dataSource.fetchEthereumAddresses().first else {
            return nil
        }

        let config: String

        if let chainId = chain?.chainId, let rpcUrl = chain?.rpcUrls.first {
            config =
                """
                var config = {
                    address: \"\(selectedAddress)\",
                    chainId: \"\(chainId)\",
                    rpcUrl: \"\(rpcUrl)\",
                    isDebug: \(isDebug)
                };
                """
        } else {
            config =
                """
                var config = {
                    address: \"\(selectedAddress)\",
                    isDebug: \(isDebug)
                };
                """
        }

        let content =
            """
            (function() {
                \(config)
                window.ethereum = new novawallet.Provider(config);
                window.web3 = new novawallet.Web3(window.ethereum);
                novawallet.postMessage = (jsonString) => {
                    webkit.messageHandlers.\(Self.subscriptionName).postMessage(jsonString)
                };
            })();
            """

        let script = DAppBrowserScript(content: content, insertionPoint: .atDocEnd)
        return script
    }

    func isIdle() -> Bool {
        state?.canHandleMessage() ?? false
    }

    func start(with dataSource: DAppBrowserStateDataSource) {
        self.dataSource = dataSource

        state = DAppMetamaskWaitingAuthState(stateMachine: self)
    }

    func process(message: Any) {
        guard
            let dict = message as? NSDictionary,
            let parsedMessage = try? dict.map(to: MetamaskMessage.self) else {
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
