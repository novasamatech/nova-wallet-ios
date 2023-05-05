import Foundation
import WalletConnectSwiftV2
import RobinHood

protocol WalletConnectTransportProtocol: DAppTransportProtocol {
    var delegate: WalletConnectTransportDelegate? { get set }

    func connect(uri: String)

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

            return wcSessions.map { wcSession in
                let dAppIcon = wcSession.peer.icons.first.flatMap { URL(string: $0) }
                let active = wcSession.expiryDate.compare(Date()) != .orderedAscending

                let wallet: MetaAccountModel?

                if
                    let settings = allSettings[wcSession.pairingTopic],
                    let metaId = settings.metaId {
                    wallet = allWallets[metaId]
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
}

extension WalletConnectTransport: WalletConnectTransportProtocol {
    func connect(uri: String) {
        service.connect(uri: uri)
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

        delegate?.walletConnectDidChangeChains(transport: self)
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

    func walletConnect(service _: WalletConnectServiceProtocol, didChange sessions: [Session]) {
        logger.debug("Sessions number: \(sessions.count)")

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
