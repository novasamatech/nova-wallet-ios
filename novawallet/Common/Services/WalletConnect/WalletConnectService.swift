import Foundation
import WalletConnectSwiftV2
import Starscream
import Combine

protocol WalletConnectServiceDelegate: AnyObject {
    func walletConnect(service: WalletConnectServiceProtocol, proposal: Session.Proposal)
    func walletConnect(service: WalletConnectServiceProtocol, establishedSession: Session)
    func walletConnect(service: WalletConnectServiceProtocol, request: Request)
    func walletConnect(service: WalletConnectServiceProtocol, error: WalletConnectServiceError)
}

protocol WalletConnectServiceProtocol: ApplicationServiceProtocol, AnyObject {
    var delegate: WalletConnectServiceDelegate? { get set }

    func connect(uri: String)

    func submit(proposalDecision: WalletConnectProposalDecision)
}

enum WalletConnectServiceError: Error {
    case setupNeeded
    case connectFailed(uri: String, internalError: Error)
    case proposalFailed(decision: WalletConnectProposalDecision, internalError: Error)
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
                guard let strongSelf = self else {
                    return
                }

                strongSelf.delegate?.walletConnect(service: strongSelf, proposal: proposal)
            }

        sessionCancellable = client?.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.delegate?.walletConnect(service: strongSelf, establishedSession: session)
            }

        requestCancellable = client?.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.delegate?.walletConnect(service: strongSelf, request: request)
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
            icons: [metadata.icon]
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

        let socketFactory = DefaultSocketFactory()
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

    private func notify(error: WalletConnectServiceError) {
        DispatchQueue.main.async {
            self.delegate?.walletConnect(service: self, error: error)
        }
    }
}

extension WalletConnectService: WalletConnectServiceProtocol {
    func connect(uri: String) {
        guard let pairingUri = WalletConnectURI(string: uri), let pairing = pairing else {
            notify(error: .setupNeeded)
            return
        }

        Task { [weak self] in
            do {
                try await pairing.pair(uri: pairingUri)
                self?.logger.debug("Pairing submitted: \(uri)")
            } catch {
                self?.logger.error("Pairing failed \(uri): \(error)")
                self?.notify(error: .connectFailed(uri: uri, internalError: error))
            }
        }
    }

    func submit(proposalDecision: WalletConnectProposalDecision) {
        guard let client = client else {
            notify(error: .setupNeeded)
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
            } catch {
                self?.logger.error("Decision submission failed: \(error)")
                self?.notify(error: .proposalFailed(decision: proposalDecision, internalError: error))
            }
        }
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
}

private final class DefaultWebSocket: WebSocket, WebSocketConnecting {
    public var isConnected: Bool {
        connected
    }

    @Atomic(defaultValue: false) private var connected: Bool

    public var onConnect: (() -> Void)?

    public var onDisconnect: ((Error?) -> Void)?

    public var onText: ((String) -> Void)?

    override init(request: URLRequest, engine: Engine) {
        super.init(request: request, engine: engine)

        onEvent = { [weak self] event in
            switch event {
            case .connected:
                self?.connected = true
                self?.onConnect?()
            case let .disconnected(message, code):
                self?.connected = false
                self?.onDisconnect?(WSError(type: .protocolError, message: message, code: code))
            case .cancelled, .reconnectSuggested:
                self?.connected = false
                self?.onDisconnect?(nil)
            case let .error(error):
                self?.connected = false
                self?.onDisconnect?(error)
            case let .text(text):
                self?.onText?(text)
            default:
                break
            }
        }
    }
}

private struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        var urlRequest = URLRequest(url: url)

        // This is specifics of Starscream due to how Origin is set
        urlRequest.addValue("allowed.domain.com", forHTTPHeaderField: "Origin")
        return DefaultWebSocket(request: urlRequest)
    }
}
