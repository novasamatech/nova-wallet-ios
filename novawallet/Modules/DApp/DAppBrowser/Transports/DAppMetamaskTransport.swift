import Foundation
import Operation_iOS
import SubstrateSdk

struct MetamaskTransportState {
    let name: String
    let dataSource: DAppBrowserStateDataSource?
    let state: DAppMetamaskStateProtocol?
}

struct PolkadotExtensionTransportState {
    let name: String
    let dataSource: DAppBrowserStateDataSource?
    let state: DAppBrowserStateProtocol?
}

enum DAppTransportState {
    case metamask(MetamaskTransportState)
    case polkadotExtension(PolkadotExtensionTransportState)

    var dataSource: DAppBrowserStateDataSource? {
        switch self {
        case let .metamask(metamaskTransportState):
            metamaskTransportState.dataSource
        case let .polkadotExtension(polkadotExtensionTransportState):
            polkadotExtensionTransportState.dataSource
        }
    }
}

final class DAppMetamaskTransport {
    static let subscriptionName = "_metamask_"

    weak var delegate: DAppBrowserTransportDelegate?
    private(set) var dataSource: DAppBrowserStateDataSource?
    private(set) var state: DAppMetamaskStateProtocol?

    private let logger: LoggerProtocol

    let isDebug: Bool

    init(
        isDebug: Bool,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.isDebug = isDebug
        self.logger = logger
    }

    private func createConfirmationRequest(
        messageId: MetamaskMessage.Id,
        host: String,
        signingOperation: JSON
    ) -> DAppOperationRequest? {
        guard let dataSource = dataSource,
              let accountId = try? state?.fetchSelectedAddress(from: dataSource)?.toAccountId() else {
            return nil
        }

        return DAppOperationRequest(
            transportName: DAppTransports.metamask,
            identifier: "\(messageId)",
            wallet: dataSource.wallet,
            accountId: accountId,
            dApp: host,
            dAppIcon: dataSource.tab?.icon,
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

    func emit(response: DAppScriptResponse, nextState: DAppMetamaskStateProtocol) {
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
        host: String,
        nextState: DAppMetamaskStateProtocol
    ) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

        if
            let request = createConfirmationRequest(
                messageId: messageId,
                host: host,
                signingOperation: signingOperation
            ) {
            if
                let chain = DAppEitherChain.createFromMetamask(
                    chain: nextState.chain,
                    dataSource: dataSource
                ) {
                if signingOperation.stringValue == nil {
                    let type = DAppSigningType.ethereumSendTransaction(chain: chain)
                    delegate?.dAppTransport(self, didReceiveConfirmation: request, of: type)
                } else {
                    let type = DAppSigningType.ethereumBytes(chain: chain)
                    delegate?.dAppTransport(self, didReceiveConfirmation: request, of: type)
                }
            } else {
                let error = DAppBrowserStateError.unexpected(reason: "Can't create chain")
                delegate?.dAppTransport(self, didReceive: error)
            }

        } else {
            let error = DAppBrowserStateError.unexpected(reason: "Can't create signing request")
            delegate?.dAppTransport(self, didReceive: error)
        }

        nextState.setup(with: dataSource)
    }

    func emitReload(with postExecutionScript: DAppScriptResponse, nextState: DAppMetamaskStateProtocol) {
        guard let dataSource = dataSource else {
            return
        }

        state = nextState

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
            guard let url = R.file.metamask_minJs.url() else {
                throw DAppBrowserInteractorError.scriptFileMissing
            }

            let content = try String(contentsOf: url)

            return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
        }
    }

    func createSubscriptionScript(for dataSource: DAppBrowserStateDataSource) -> DAppBrowserScript? {
        guard let state = state else {
            return nil
        }

        let addressComponent: String

        if let selectedAddress = state.fetchSelectedAddress(from: dataSource) {
            addressComponent = "address: \"\(selectedAddress)\","
        } else {
            addressComponent = ""
        }

        let chain = state.chain

        let config: String

        if let rpcUrl = chain.rpcUrls.first {
            config =
                """
                var config = {
                    \(addressComponent)
                    chainId: \"\(chain.chainId)\",
                    rpcUrl: \"\(rpcUrl)\",
                    isDebug: \(isDebug)
                };
                """
        } else {
            config =
                """
                var config = {
                    \(addressComponent)
                    chainId: \"\(chain.chainId)\",
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

    func bringPhishingDetectedStateIfNeeded() -> Bool {
        guard let state = state else {
            return false
        }

        let isPhishingState = state as? DAppMetamaskPhishingDetectedState

        if isPhishingState != nil {
            return false
        }

        self.state = DAppMetamaskPhishingDetectedState(stateMachine: self, chain: state.chain)

        return true
    }

    func start(with dataSource: DAppBrowserStateDataSource) {
        self.dataSource = dataSource

        state = DAppMetamaskWaitingAuthState(stateMachine: self, chain: .etheremChain)
    }

    func process(message: Any, host: String) {
        do {
            guard let dict = message as? NSDictionary else {
                delegate?.dAppTransport(self, didReceive: DAppBrowserInteractorError.unexpectedMessageType)
                return
            }

            let parsedMessage = try dict.map(to: MetamaskMessage.self)

            guard let dataSource = dataSource else {
                return
            }

            state?.handle(message: parsedMessage, host: host, dataSource: dataSource)
        } catch {
            delegate?.dAppTransport(self, didReceive: DAppBrowserInteractorError.unexpectedMessageType)
        }
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

    func makeOpaqueState() -> DAppTransportState? {
        let transportState = MetamaskTransportState(
            name: name,
            dataSource: dataSource,
            state: state
        )

        return .metamask(transportState)
    }

    func restoreState(from state: DAppTransportState) {
        guard case let .metamask(metamaskTransportState) = state else {
            return
        }

        self.state = metamaskTransportState.state
        self.state?.stateMachine = self
        dataSource = metamaskTransportState.dataSource

        logger.info("\(String(describing: self)) did restore \(metamaskTransportState.name) transport state")
    }
}
