import UIKit
import WalletConnectSwiftV2

final class WalletConnectInteractor {
    let presenter: WalletConnectInteractorOutputProtocol
    let transport: WalletConnectTransportProtocol
    let securedLayer: SecurityLayerServiceProtocol
    let urlHandlingFacade: URLHandlingServiceFacadeProtocol

    weak var mediator: DAppInteractionMediating?

    private var delegates: [WeakWrapper] = []

    init(
        transport: WalletConnectTransportProtocol,
        presenter: WalletConnectInteractorOutputProtocol,
        securedLayer: SecurityLayerServiceProtocol,
        urlHandlingFacade: URLHandlingServiceFacadeProtocol
    ) {
        self.transport = transport
        self.presenter = presenter
        self.securedLayer = securedLayer
        self.urlHandlingFacade = urlHandlingFacade
    }

    private func subscribeUrlHandling() {
        guard let wcUrlHandler: WalletConnectUrlParsingService = urlHandlingFacade.findInternalService() else {
            return
        }

        handleUrlLink(from: wcUrlHandler)

        wcUrlHandler.pendingUrl.addObserver(with: self) { [weak self, weak wcUrlHandler] _, _ in
            guard let handler = wcUrlHandler else {
                return
            }

            self?.handleUrlLink(from: handler)
        }
    }

    private func handleUrlLink(from handler: WalletConnectUrlParsingService) {
        guard let newUrl = handler.pendingUrl.state else {
            return
        }

        handler.pendingUrl.state = nil

        transport.connect(uri: newUrl, completion: { _ in })
    }
}

extension WalletConnectInteractor: WalletConnectInteractorInputProtocol {}

extension WalletConnectInteractor: WalletConnectDelegateInputProtocol {
    func connect(uri: String, completion: @escaping (Error?) -> Void) {
        transport.connect(uri: uri) { [weak self] optError in
            self?.securedLayer.scheduleExecutionIfAuthorized {
                completion(optError)
            }
        }
    }

    func add(delegate: WalletConnectDelegateOutputProtocol) {
        remove(delegate: delegate)

        delegates.append(WeakWrapper(target: delegate))
    }

    func remove(delegate: WalletConnectDelegateOutputProtocol) {
        delegates = delegates.filter { wrapper in
            wrapper.target != nil && wrapper.target !== delegate
        }
    }

    func getSessionsCount() -> Int {
        transport.getSessionsCount()
    }

    func fetchSessions(_ completion: @escaping (Result<[WalletConnectSession], Error>) -> Void) {
        transport.fetchSessions(completion)
    }

    func disconnect(from session: String, completion: @escaping (Error?) -> Void) {
        transport.disconnect(from: session) { [weak self] optError in
            self?.securedLayer.scheduleExecutionIfAuthorized {
                completion(optError)
            }
        }
    }
}

extension WalletConnectInteractor: WalletConnectTransportDelegate {
    func walletConnect(
        transport: WalletConnectTransportProtocol,
        didReceive message: WalletConnectTransportMessage
    ) {
        mediator?.process(message: message, host: message.host, transport: transport.name)
    }

    func walletConnect(
        transport _: WalletConnectTransportProtocol,
        didFail error: WalletConnectTransportError
    ) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.presenter.didReceive(error: error)
        }
    }

    func walletConnect(transport _: WalletConnectTransportProtocol, authorize request: DAppAuthRequest) {
        mediator?.process(authRequest: request)
    }

    func walletConnect(
        transport _: WalletConnectTransportProtocol,
        sign request: DAppOperationRequest,
        type: DAppSigningType
    ) {
        mediator?.process(signingRequest: request, type: type)
    }

    func walletConnectDidChangeSessions(transport _: WalletConnectTransportProtocol) {
        delegates.forEach { wrapper in
            guard let target = wrapper.target as? WalletConnectDelegateOutputProtocol else {
                return
            }

            return target.walletConnectDidChangeSessions()
        }
    }

    func walletConnectDidChangeChains(transport _: WalletConnectTransportProtocol) {
        delegates.forEach { wrapper in
            guard let target = wrapper.target as? WalletConnectDelegateOutputProtocol else {
                return
            }

            return target.walletConnectDidChangeChains()
        }
    }

    func walletConnectAskNextMessage(transport _: WalletConnectTransportProtocol) {
        mediator?.processMessageQueue()
    }
}

extension WalletConnectInteractor: DAppInteractionChildProtocol {
    func setup() {
        transport.delegate = self
        mediator?.register(transport: transport)

        subscribeUrlHandling()
    }

    func throttle() {
        mediator?.unregister(transport: transport)
    }

    func completePhishingStateHandling() {
        // do nothing as wallet connect continues working after phishing detected
    }
}
