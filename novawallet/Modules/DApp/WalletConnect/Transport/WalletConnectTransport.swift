import Foundation
import WalletConnectSwiftV2

protocol WalletConnectTransportProtocol: DAppTransportProtocol {
    var delegate: WalletConnectTransportDelegate? { get set }

    func connect(uri: String)

    func getSessionsCount() -> Int
}

protocol WalletConnectTransportDelegate: AnyObject {
    func walletConnect(
        transport: WalletConnectTransportProtocol,
        didReceive message: WalletConnectTransportMessage
    )

    func walletConnect(transport: WalletConnectTransportProtocol, authorize request: DAppAuthRequest)

    func walletConnect(
        transport: WalletConnectTransportProtocol,
        sign request: DAppOperationRequest,
        type: DAppSigningType
    )

    func walletConnect(transport: WalletConnectTransportProtocol, didFail error: WalletConnectTransportError)

    func walletConnectDidChangeSessions(transport: WalletConnectTransportProtocol)

    func walletConnectAskNextMessage(transport: WalletConnectTransportProtocol)
}

final class WalletConnectTransport {
    let service: WalletConnectServiceProtocol
    let dataSource: DAppStateDataSource
    let logger: LoggerProtocol

    weak var delegate: WalletConnectTransportDelegate?

    private var state: WalletConnectStateProtocol?

    init(
        service: WalletConnectServiceProtocol,
        dataSource: DAppStateDataSource,
        logger: LoggerProtocol
    ) {
        self.service = service
        self.dataSource = dataSource
        self.logger = logger
    }
}

extension WalletConnectTransport: WalletConnectTransportProtocol {
    func connect(uri: String) {
        service.connect(uri: uri)
    }

    func getSessionsCount() -> Int {
        service.getSessions().count
    }
}

extension WalletConnectTransport {
    var name: String { DAppTransports.walletConnect }

    func isIdle() -> Bool {
        state?.canHandleMessage() ?? false
    }

    func bringPhishingDetectedStateIfNeeded() -> Bool {
        // TODO: Handle phishing transition
        true
    }

    func process(message: Any, host _: String?) {
        guard let message = message as? WalletConnectTransportMessage else {
            return
        }

        state?.handle(message: message, dataSource: dataSource)
    }

    func processConfirmation(response: DAppOperationResponse) {
        state?.handleOperation(response: response, dataSource: dataSource)
    }

    func processAuth(response: DAppAuthResponse) {
        state?.handleAuth(response: response, dataSource: dataSource)
    }

    func processChainsChanges() {
        state?.proceed(with: dataSource)
    }

    func start() {
        service.delegate = self
        service.setup()

        state = WalletConnectStateInitiating(stateMachine: self)
        state?.proceed(with: dataSource)
    }

    func stop() {
        service.throttle()
    }
}

extension WalletConnectTransport: WalletConnectStateMachineProtocol {
    func emit(nextState: WalletConnectStateProtocol) {
        let prevCanHandleMessage = state?.canHandleMessage() ?? false

        state = nextState

        nextState.proceed(with: dataSource)

        if !prevCanHandleMessage, nextState.canHandleMessage() {
            delegate?.walletConnectAskNextMessage(transport: self)
        }
    }

    func emit(authRequest: DAppAuthRequest, nextState: WalletConnectStateProtocol) {
        state = nextState

        delegate?.walletConnect(transport: self, authorize: authRequest)

        nextState.proceed(with: dataSource)
    }

    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: WalletConnectStateProtocol
    ) {
        state = nextState

        delegate?.walletConnect(transport: self, sign: signingRequest, type: type)

        nextState.proceed(with: dataSource)
    }

    func emit(proposalDecision: WalletConnectProposalDecision, nextState: WalletConnectStateProtocol) {
        state = nextState

        service.submit(proposalDecision: proposalDecision)

        nextState.proceed(with: dataSource)
    }

    func emit(signDecision: WalletConnectSignDecision, nextState: WalletConnectStateProtocol) {
        state = nextState

        service.submit(signingDecision: signDecision)

        nextState.proceed(with: dataSource)
    }

    func emit(error: WalletConnectStateError, nextState: WalletConnectStateProtocol) {
        state = nextState

        delegate?.walletConnect(transport: self, didFail: .stateFailed(error))

        nextState.proceed(with: dataSource)
    }
}

extension WalletConnectTransport: WalletConnectServiceDelegate {
    func walletConnect(service _: WalletConnectServiceProtocol, proposal: Session.Proposal) {
        logger.debug("Proposal: \(proposal)")

        delegate?.walletConnect(transport: self, didReceive: .proposal(proposal))
    }

    func walletConnect(service _: WalletConnectServiceProtocol, establishedSession: Session) {
        logger.debug("New session: \(establishedSession)")

        delegate?.walletConnectDidChangeSessions(transport: self)
    }

    func walletConnect(service _: WalletConnectServiceProtocol, request: Request, session: Session?) {
        logger.debug("New session: \(request)")

        delegate?.walletConnect(transport: self, didReceive: .request(request, session))
    }

    func walletConnect(service _: WalletConnectServiceProtocol, error: WalletConnectServiceError) {
        logger.error("Error: \(error)")

        delegate?.walletConnect(transport: self, didFail: .serviceFailed(error))
    }
}
