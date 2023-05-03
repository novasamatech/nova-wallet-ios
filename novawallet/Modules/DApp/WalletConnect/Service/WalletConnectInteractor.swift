import UIKit
import WalletConnectSwiftV2

final class WalletConnectInteractor {
    let presenter: WalletConnectInteractorOutputProtocol
    let transport: WalletConnectTransportProtocol

    weak var mediator: DAppInteractionMediating?

    private var delegates: [WeakWrapper] = []

    init(
        transport: WalletConnectTransportProtocol,
        presenter: WalletConnectInteractorOutputProtocol
    ) {
        self.transport = transport
        self.presenter = presenter
    }
}

extension WalletConnectInteractor: WalletConnectInteractorInputProtocol {}

extension WalletConnectInteractor: WalletConnectDelegateInputProtocol {
    func connect(uri: String) {
        transport.connect(uri: uri)
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
        didFail _: WalletConnectTransportError
    ) {
        // TODO: Handle error
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

    func walletConnectAskNextMessage(transport _: WalletConnectTransportProtocol) {
        mediator?.processMessageQueue()
    }
}

extension WalletConnectInteractor: DAppInteractionChildProtocol {
    func setup() {
        transport.delegate = self
        mediator?.register(transport: transport)
    }

    func throttle() {
        mediator?.unregister(transport: transport)
    }
}
