import Foundation
import WalletConnectSwiftV2
import Operation_iOS

protocol WalletConnectTransportProtocol: DAppTransportProtocol {
    var delegate: WalletConnectTransportDelegate? { get set }

    func connect(uri: String, completion: @escaping (Error?) -> Void)

    func getSessionsCount() -> Int

    func fetchSessions(_ completion: @escaping (Result<[WalletConnectSession], Error>) -> Void)

    func disconnect(from session: String, completion: @escaping (Error?) -> Void)
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

    func walletConnectDidChangeChains(transport: WalletConnectTransportProtocol)

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

    private func createSessionsMappingOperation(
        dependingOn allSettingsOperation: BaseOperation<[DAppSettings]>,
        allWalletsOperation: BaseOperation<[MetaAccountModel]>,
        wcSessions: [Session],
        chainsStore: ChainsStoreProtocol
    ) -> BaseOperation<[WalletConnectSession]> {
        ClosureOperation<[WalletConnectSession]> {
            let allSettings = try allSettingsOperation.extractNoCancellableResultData().reduceToDict()
            let allWallets = try allWalletsOperation.extractNoCancellableResultData().reduceToDict()

            return wcSessions.sorted(
                by: { $0.expiryDate.compare($1.expiryDate) == .orderedDescending }
            ).map { wcSession in
                let dAppIcon = wcSession.peer.icons.first.flatMap { URL(string: $0) }
                let active = wcSession.expiryDate.compare(Date()) != .orderedAscending

                let wallet: MetaAccountModel?

                if
                    let settings = allSettings[wcSession.pairingTopic] {
                    wallet = allWallets[settings.metaId]
                } else {
                    wallet = nil
                }

                let networks = WalletConnectModelFactory.createSessionChainsResolution(
                    from: wcSession,
                    chainsStore: chainsStore
                )

                return WalletConnectSession(
                    sessionId: wcSession.topic,
                    pairingId: wcSession.pairingTopic,
                    wallet: wallet,
                    networks: networks,
                    dAppName: wcSession.peer.name,
                    dAppHost: wcSession.peer.url,
                    dAppIcon: dAppIcon,
                    active: active
                )
            }
        }
    }

    private func checkStateTransition(
        from oldState: WalletConnectStateProtocol?,
        to newState: WalletConnectStateProtocol
    ) {
        let prevCanHandleMessage = oldState?.canHandleMessage() ?? false

        if !prevCanHandleMessage, newState.canHandleMessage() {
            delegate?.walletConnectAskNextMessage(transport: self)
        }
    }
}

extension WalletConnectTransport: WalletConnectTransportProtocol {
    func connect(uri: String, completion: @escaping (Error?) -> Void) {
        service.connect(uri: uri, completion: completion)
    }

    func getSessionsCount() -> Int {
        service.getSessions().count
    }

    func fetchSessions(_ completion: @escaping (Result<[WalletConnectSession], Error>) -> Void) {
        let wcSessions = service.getSessions()

        guard !wcSessions.isEmpty else {
            completion(.success([]))
            return
        }

        let allSettingsOperation = dataSource.dAppSettingsRepository.fetchAllOperation(with: .init())
        let allWalletsOperation = dataSource.walletsRepository.fetchAllOperation(with: .init())

        let mapOperation = createSessionsMappingOperation(
            dependingOn: allSettingsOperation,
            allWalletsOperation: allWalletsOperation,
            wcSessions: wcSessions,
            chainsStore: dataSource.chainsStore
        )

        mapOperation.addDependency(allSettingsOperation)
        mapOperation.addDependency(allWalletsOperation)

        let operations = [allSettingsOperation, allWalletsOperation, mapOperation]

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let sessions = try mapOperation.extractNoCancellableResultData()

                    completion(.success(sessions))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        dataSource.operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    func disconnect(from session: String, completion: @escaping (Error?) -> Void) {
        service.disconnect(from: session, completion: completion)
    }
}

extension WalletConnectTransport {
    var name: String { DAppTransports.walletConnect }

    func isIdle() -> Bool {
        state?.canHandleMessage() ?? false
    }

    func bringPhishingDetectedStateIfNeeded() -> Bool {
        // just notify user but remain in the same state
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

        delegate?.walletConnectDidChangeChains(transport: self)
    }

    func start() {
        service.delegate = self
        service.setup()

        state = WalletConnectStateInitiating(stateMachine: self, logger: logger)
        state?.proceed(with: dataSource)
    }

    func stop() {
        service.throttle()
    }
}

extension WalletConnectTransport: WalletConnectStateMachineProtocol {
    func emit(nextState: WalletConnectStateProtocol) {
        let oldState = state
        state = nextState

        nextState.proceed(with: dataSource)

        checkStateTransition(from: oldState, to: nextState)
    }

    func emit(authRequest: DAppAuthRequest, nextState: WalletConnectStateProtocol) {
        let oldState = state
        state = nextState

        delegate?.walletConnect(transport: self, authorize: authRequest)

        nextState.proceed(with: dataSource)

        checkStateTransition(from: oldState, to: nextState)
    }

    func emit(
        signingRequest: DAppOperationRequest,
        type: DAppSigningType,
        nextState: WalletConnectStateProtocol
    ) {
        let oldState = state
        state = nextState

        delegate?.walletConnect(transport: self, sign: signingRequest, type: type)

        nextState.proceed(with: dataSource)

        checkStateTransition(from: oldState, to: nextState)
    }

    func emit(
        proposalDecision: WalletConnectProposalDecision,
        nextState: WalletConnectStateProtocol,
        error: WalletConnectStateError?
    ) {
        let oldState = state
        state = nextState

        service.submit(proposalDecision: proposalDecision) { [weak self] optError in
            if let error = optError, let self = self {
                self.delegate?.walletConnect(
                    transport: self,
                    didFail: .proposalDecisionSubmissionFailed(error)
                )
            }
        }

        if let error = error {
            delegate?.walletConnect(transport: self, didFail: .stateFailed(error))
        }

        nextState.proceed(with: dataSource)

        checkStateTransition(from: oldState, to: nextState)
    }

    func emit(
        signDecision: WalletConnectSignDecision,
        nextState: WalletConnectStateProtocol,
        error: WalletConnectStateError?
    ) {
        let oldState = state
        state = nextState

        service.submit(signingDecision: signDecision) { [weak self] optError in
            if let error = optError, let self = self {
                self.delegate?.walletConnect(transport: self, didFail: .signingDecisionSubmissionFailed(error))
            }
        }

        if let error = error {
            delegate?.walletConnect(transport: self, didFail: .stateFailed(error))
        }

        nextState.proceed(with: dataSource)

        checkStateTransition(from: oldState, to: nextState)
    }

    func emit(error: WalletConnectStateError, nextState: WalletConnectStateProtocol) {
        let oldState = state
        state = nextState

        delegate?.walletConnect(transport: self, didFail: .stateFailed(error))

        nextState.proceed(with: dataSource)

        checkStateTransition(from: oldState, to: nextState)
    }
}

extension WalletConnectTransport: WalletConnectServiceDelegate {
    func walletConnect(service _: WalletConnectServiceProtocol, proposal: Session.Proposal) {
        logger.debug("Proposal: \(proposal)")

        delegate?.walletConnect(transport: self, didReceive: .proposal(proposal))
    }

    func walletConnect(service _: WalletConnectServiceProtocol, didChange sessions: [Session]) {
        logger.debug("Sessions number: \(sessions.count)")

        delegate?.walletConnectDidChangeSessions(transport: self)
    }

    func walletConnect(service _: WalletConnectServiceProtocol, request: Request, session: Session?) {
        logger.debug("New session: \(request)")

        delegate?.walletConnect(transport: self, didReceive: .request(request, session))
    }
}
