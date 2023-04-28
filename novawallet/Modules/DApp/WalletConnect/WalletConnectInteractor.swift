import UIKit
import WalletConnectSwiftV2

final class WalletConnectInteractor {
    weak var presenter: WalletConnectInteractorOutputProtocol?

    let transport: WalletConnectTransportProtocol
    let mediator: DAppInteractionMediating

    init(mediator: DAppInteractionMediating, transport: WalletConnectTransportProtocol) {
        self.mediator = mediator
        self.transport = transport
    }

    deinit {
        mediator.unregister(transport: transport)
    }
}

extension WalletConnectInteractor: WalletConnectInteractorInputProtocol {
    func setup() {
        transport.delegate = self
        mediator.register(transport: transport)
    }

    func connect(uri: String) {
        transport.connect(uri: uri)
    }
}

extension WalletConnectInteractor: WalletConnectTransportDelegate {
    func walletConnect(
        transport: WalletConnectTransportProtocol,
        didReceive message: WalletConnectTransportMessage
    ) {
        mediator.process(message: message, host: message.host, transport: transport.name)
    }

    func walletConnect(
        transport _: WalletConnectTransportProtocol,
        didFail _: WalletConnectTransportError
    ) {
        // TODO: Handle error
    }

    func walletConnect(transport _: WalletConnectTransportProtocol, authorize request: DAppAuthRequest) {
        mediator.process(authRequest: request)
    }

    func walletConnect(
        transport _: WalletConnectTransportProtocol,
        sign request: DAppOperationRequest,
        type: DAppSigningType
    ) {
        mediator.process(signingRequest: request, type: type)
    }

    func walletConnectAskNextMessage(transport _: WalletConnectTransportProtocol) {
        mediator.processMessageQueue()
    }
}
