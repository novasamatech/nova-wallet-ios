import Foundation
import WalletConnectSwiftV2
import Starscream
import Combine

protocol WalletConnectServiceDelegate: AnyObject {
    func walletConnect(service: WalletConnectServiceProtocol, proposal: Session.Proposal)
    func walletConnect(service: WalletConnectServiceProtocol, didChange sessions: [Session])
    func walletConnect(service: WalletConnectServiceProtocol, request: Request, session: Session?)
}

protocol WalletConnectServiceProtocol: ApplicationServiceProtocol, AnyObject {
    var delegate: WalletConnectServiceDelegate? { get set }

    func connect(uri: String, completion: @escaping (Error?) -> Void)

    func submit(proposalDecision: WalletConnectProposalDecision, completion: @escaping (Error?) -> Void)
    func submit(signingDecision: WalletConnectSignDecision, completion: @escaping (Error?) -> Void)

    func getSessions() -> [Session]

    func disconnect(from session: String, completion: @escaping (Error?) -> Void)
}

final class WalletConnectService {
    private var networking: NetworkingInteractor?
    @Atomic(defaultValue: nil) private var pairing: PairingClient?
    private var client: SignClient?

    @Atomic(defaultValue: nil) private var proposalCancellable: AnyCancellable?
    @Atomic(defaultValue: nil) private var sessionCancellable: AnyCancellable?
    @Atomic(defaultValue: nil) private var requestCancellable: AnyCancellable?

    weak var delegate: WalletConnectServiceDelegate?

    let relayHost: String
    let logger: LoggerProtocol
    let metadata: WalletConnectMetadata

    init(
        metadata: WalletConnectMetadata,
        relayHost: String = "relay.walletconnect.com",
        logger: LoggerProtocol = Logger.shared
    ) {
        self.metadata = metadata
        self.relayHost = relayHost
        self.logger = logger
    }

    private func setupSubscription() {
        proposalCancellable = client?.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal in
                guard let self = self else {
                    return
                }

                self.delegate?.walletConnect(service: self, proposal: proposal)
            }

        sessionCancellable = client?.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self = self else {
                    return
                }

                self.delegate?.walletConnect(service: self, didChange: sessions)
            }

        requestCancellable = client?.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                guard let self = self else {
                    return
                }

                let session = self.client?.getSessions().first { $0.topic == request.topic }

                self.delegate?.walletConnect(
                    service: self,
                    request: request,
                    session: session
                )
            }
    }

    private func clearSubscriptions() {
        proposalCancellable?.cancel()
        proposalCancellable = nil

        sessionCancellable?.cancel()
        sessionCancellable = nil

        requestCancellable?.cancel()
        requestCancellable = nil
    }

    private func setupClient() {
        guard client == nil, let pairing = pairing, let networking = networking else {
            return
        }

        let metadata = AppMetadata(
            name: metadata.name,
            description: metadata.description,
            url: metadata.website,
            icons: [metadata.icon],
            redirect: .init(
                native: metadata.redirect.native,
                universal: metadata.redirect.universal
            )
        )

        client = SignClientFactory.create(
            metadata: metadata,
            pairingClient: pairing,
            networkingClient: networking
        )
    }

    private func clearClient() {
        client = nil
    }

    private func setupPairing() {
        guard pairing == nil, let networking = networking else {
            return
        }

        pairing = PairingClientFactory.create(networkingClient: networking)
    }

    private func clearPairing() {
        pairing = nil
    }

    private func setupNetworking() {
        guard networking == nil else {
            return
        }

        let socketFactory = DefaultSocketFactory(logger: logger)
        let relayClient = RelayClient(relayHost: relayHost, projectId: metadata.projectId, socketFactory: socketFactory)
        networking = NetworkingClientFactory.create(relayClient: relayClient)
    }

    private func clearNetworking() {
        do {
            try networking?.disconnect(closeCode: .normalClosure)
        } catch {
            logger.error("Disconnection failed: \(error)")
        }

        networking = nil
    }

    private func notify(completion: @escaping (Error?) -> Void, error: Error?) {
        DispatchQueue.main.async {
            completion(error)
        }
    }
}

extension WalletConnectService: WalletConnectServiceProtocol {
    func connect(uri: String, completion: @escaping (Error?) -> Void) {
        guard let pairingUri = WalletConnectURI(string: uri), let pairing = pairing else {
            notify(completion: completion, error: CommonError.dataCorruption)
            return
        }

        Task { [weak self] in
            do {
                try await pairing.pair(uri: pairingUri)
                self?.logger.debug("Pairing submitted: \(uri)")
                self?.notify(completion: completion, error: nil)
            } catch {
                self?.logger.error("Pairing failed \(uri): \(error)")
                self?.notify(completion: completion, error: error)
            }
        }
    }

    func submit(proposalDecision: WalletConnectProposalDecision, completion: @escaping (Error?) -> Void) {
        guard let client = client else {
            notify(completion: completion, error: CommonError.undefined)
            return
        }

        Task { [weak self] in
            do {
                switch proposalDecision {
                case let .approve(proposal, namespaces):
                    try await client.approve(proposalId: proposal.id, namespaces: namespaces)
                case let .reject(proposal):
                    try await client.reject(proposalId: proposal.id, reason: .userRejected)
                }

                self?.notify(completion: completion, error: nil)
            } catch {
                self?.logger.error("Decision submission failed: \(error)")
                self?.notify(completion: completion, error: error)
            }
        }
    }

    func submit(signingDecision: WalletConnectSignDecision, completion: @escaping (Error?) -> Void) {
        guard let client = client else {
            notify(completion: completion, error: CommonError.undefined)
            return
        }

        Task { [weak self] in
            do {
                try await client.respond(
                    topic: signingDecision.request.topic,
                    requestId: signingDecision.request.id,
                    response: signingDecision.result
                )

                self?.notify(completion: completion, error: nil)
            } catch {
                self?.logger.error("Signature submission failed: \(error)")
                self?.notify(completion: completion, error: error)
            }
        }
    }

    func getSessions() -> [Session] {
        guard let client = client else {
            return []
        }

        return client.getSessions()
    }

    func setup() {
        setupNetworking()
        setupPairing()
        setupClient()
        setupSubscription()
    }

    func throttle() {
        clearNetworking()
        clearPairing()
        clearClient()
        clearSubscriptions()
    }

    func disconnect(from session: String, completion: @escaping (Error?) -> Void) {
        Task { [weak self] in
            do {
                try await self?.client?.disconnect(topic: session)

                self?.notify(completion: completion, error: nil)

            } catch {
                self?.logger.error("Disconnecting \(session) failed: \(error)")

                self?.notify(completion: completion, error: error)
            }
        }
    }
}

private final class DefaultWebSocket: WebSocketConnecting {
    public var isConnected: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connected
    }

    private var connected: Bool = false

    public var onConnect: (() -> Void)?

    public var onDisconnect: ((Error?) -> Void)?

    public var onText: ((String) -> Void)?

    private var webSocket: WebSocket?

    let logger: LoggerProtocol
    let engineFactory: WebSocketEngineFactoryProtocol
    let mutex = NSLock()
    var request: URLRequest

    init(request: URLRequest, engineFactory: WebSocketEngineFactoryProtocol, logger: LoggerProtocol) {
        self.engineFactory = engineFactory
        self.request = request
        self.logger = logger
    }

    func connect() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        logger.debug("Will connect")

        stopWebsocket()
        startWebsocket()
    }

    func disconnect() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        connected = false

        logger.debug("Will disconnect")

        stopWebsocket()
    }

    func write(string: String, completion: (() -> Void)?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        webSocket?.write(string: string, completion: completion)
    }

    private func startWebsocket() {
        let engine = engineFactory.createEngine()
        webSocket = WebSocket(request: request, engine: engine)

        webSocket?.onEvent = { [weak self] event in
            self?.logger.debug("Did receive event: \(event)")

            switch event {
            case .connected:
                self?.markConnectedAndNotify()
            case let .disconnected(message, code):
                self?.markDisconnectedAndNotify(
                    error: WSError(type: .protocolError, message: message, code: code)
                )
            case .cancelled:
                self?.markDisconnectedAndNotify(error: nil)
            case .reconnectSuggested:
                self?.protectedRestart()
            case let .viabilityChanged(isViable):
                if isViable {
                    self?.protectedRestart()
                } else {
                    self?.markDisconnectedAndNotify(error: nil)
                }
            case let .error(error):
                self?.markDisconnectedAndNotify(error: error)
            case let .text(text):
                self?.onText?(text)
            case .binary:
                self?.logger.warning("Binary received but not supported")
            case .ping, .pong:
                break
            }
        }

        webSocket?.connect()
    }

    private func stopWebsocket() {
        webSocket?.onEvent = nil
        webSocket?.forceDisconnect()
        webSocket = nil
    }

    private func protectedRestart() {
        mutex.lock()

        stopWebsocket()
        startWebsocket()

        mutex.unlock()
    }

    private func markConnectedAndNotify() {
        mutex.lock()

        connected = true

        mutex.unlock()

        onConnect?()
    }

    private func markDisconnectedAndNotify(error: Error?) {
        mutex.lock()

        connected = false

        stopWebsocket()

        mutex.unlock()

        onDisconnect?(error)
    }
}

private protocol WebSocketEngineFactoryProtocol {
    func createEngine() -> Engine
}

private final class DefaultEngineFactory: WebSocketEngineFactoryProtocol {
    func createEngine() -> Engine {
        WSEngine(
            transport: FoundationTransport(),
            certPinner: FoundationSecurity(),
            compressionHandler: nil
        )
    }
}

private final class DefaultSocketFactory: WebSocketFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func create(with url: URL) -> WebSocketConnecting {
        var urlRequest = URLRequest(url: url)

        // This is specifics of Starscream due to how Origin is set
        urlRequest.addValue("allowed.domain.com", forHTTPHeaderField: "Origin")

        return DefaultWebSocket(request: urlRequest, engineFactory: DefaultEngineFactory(), logger: logger)
    }
}
