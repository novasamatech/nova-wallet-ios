import Foundation
import WalletConnectSign
import Starscream
import Combine
import CryptoSwift
import Web3Core

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
    private var eventsClient: EventsClient?

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
            .sink { [weak self] proposalAndContext in
                guard let self = self else {
                    return
                }

                self.delegate?.walletConnect(service: self, proposal: proposalAndContext.proposal)
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
            .sink { [weak self] requestAndContext in
                guard let self = self else {
                    return
                }

                let session = self.client?.getSessions().first { $0.topic == requestAndContext.request.topic }

                self.delegate?.walletConnect(
                    service: self,
                    request: requestAndContext.request,
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
        guard
            client == nil,
            let pairing,
            let networking,
            let eventsClient else {
            return
        }

        do {
            let redirect = try AppMetadata.Redirect(
                native: metadata.redirect.native,
                universal: metadata.redirect.universal
            )

            let wcMetadata = AppMetadata(
                name: metadata.name,
                description: metadata.description,
                url: metadata.website,
                icons: [metadata.icon],
                redirect: redirect
            )

            client = SignClientFactory.create(
                metadata: wcMetadata,
                pairingClient: pairing,
                projectId: metadata.projectId,
                crypto: DefaultCryptoProvider(),
                networkingClient: networking,
                groupIdentifier: SharedContainerGroup.name,
                eventsClient: eventsClient
            )
        } catch {
            logger.error("Unexpected setup error: \(error)")
        }
    }

    private func clearClient() {
        client = nil
    }

    private func setupPairing() {
        guard
            pairing == nil,
            let networking,
            let eventsClient else {
            return
        }

        pairing = PairingClientFactory.create(
            networkingClient: networking,
            eventsClient: eventsClient,
            groupIdentifier: SharedContainerGroup.name
        )
    }

    private func clearPairing() {
        pairing = nil
    }

    private func setupEventsClient() {
        eventsClient = EventsClientFactory.createWithDefaultStorage(
            projectId: metadata.projectId,
            sdkVersion: EnvironmentInfo.sdkName
        )
    }

    private func clearEventsClient() {
        eventsClient = nil
    }

    private func setupNetworking() {
        guard networking == nil else {
            return
        }

        let socketFactory = DefaultSocketFactory(logger: logger)

        let relayClient = RelayClientFactory.create(
            relayHost: relayHost,
            projectId: metadata.projectId,
            socketFactory: socketFactory,
            groupIdentifier: SharedContainerGroup.name,
            socketConnectionType: .automatic
        )

        networking = NetworkingClientFactory.create(
            relayClient: relayClient,
            groupIdentifier: SharedContainerGroup.name
        )
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
        guard let pairing = pairing else {
            notify(completion: completion, error: CommonError.dataCorruption)
            return
        }

        Task { [weak self] in
            do {
                let pairingUri = try WalletConnectURI(uriString: uri)
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
                    _ = try await client.approve(proposalId: proposal.id, namespaces: namespaces)
                case let .reject(proposal):
                    try await client.rejectSession(proposalId: proposal.id, reason: .userRejected)
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
        setupEventsClient()
        setupPairing()
        setupClient()
        setupSubscription()
    }

    func throttle() {
        clearNetworking()
        clearPairing()
        clearClient()
        clearEventsClient()
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
    enum ConnectionState: Equatable {
        case notConnected
        case connecting
        case connected
    }

    public var isConnected: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connectionState == .connected
    }

    private var connectionState: ConnectionState = .notConnected

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

        guard connectionState != .connecting else {
            logger.warning("Already connecting. Skipped...")
            return
        }

        logger.debug("Will connect")

        connectionState = .connecting

        stopWebsocket()
        startWebsocket()
    }

    func disconnect() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        connectionState = .notConnected

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

    private func handleEvent(_ event: WebSocketEvent) {
        switch event {
        case .connected:
            markConnectedAndNotify()
        case let .disconnected(message, code):
            markDisconnectedAndNotify(
                error: WSError(type: .protocolError, message: message, code: code)
            )
        case .cancelled:
            markDisconnectedAndNotify(error: nil)
        case let .reconnectSuggested(isBetter):
            if isBetter {
                protectedRestartIfDisconnected()
            }
        case let .viabilityChanged(isViable):
            if isViable {
                protectedRestartIfDisconnected()
            }
        case let .error(error):
            markDisconnectedAndNotify(error: error)
        case let .text(text):
            onText?(text)
        case .binary:
            logger.warning("Binary received but not supported")
        case .ping, .pong:
            break
        }
    }

    private func startWebsocket() {
        let engine = engineFactory.createEngine()
        webSocket = WebSocket(request: request, engine: engine)

        webSocket?.onEvent = { [weak self] event in
            self?.logger.debug("Did receive event: \(event)")

            self?.handleEvent(event)
        }

        webSocket?.connect()
    }

    private func stopWebsocket() {
        webSocket?.onEvent = nil
        webSocket?.forceDisconnect()
        webSocket = nil
    }

    private func protectedRestartIfDisconnected() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard connectionState == .notConnected else {
            return
        }

        connectionState = .connecting

        startWebsocket()
    }

    private func markConnectedAndNotify() {
        mutex.lock()

        connectionState = .connected

        mutex.unlock()

        onConnect?()
    }

    private func markDisconnectedAndNotify(error: Error?) {
        mutex.lock()

        connectionState = .notConnected

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
            transport: TCPTransport(),
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

private struct DefaultCryptoProvider: CryptoProvider {
    enum InternalError: Error {
        case invalidSignatureOrMessage
    }

    public func recoverPubKey(signature: WalletConnectSign.EthereumSignature, message: Data) throws -> Data {
        guard
            let publicKey = SECP256K1.recoverPublicKey(
                hash: message,
                signature: signature.serialized
            ) else {
            throw InternalError.invalidSignatureOrMessage
        }

        return publicKey
    }

    public func keccak256(_ data: Data) -> Data {
        let digest = SHA3(variant: .keccak256)
        let hash = digest.calculate(for: [UInt8](data))
        return Data(hash)
    }
}
