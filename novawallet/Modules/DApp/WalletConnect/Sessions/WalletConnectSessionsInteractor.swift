import UIKit

final class WalletConnectSessionsInteractor {
    weak var presenter: WalletConnectSessionsInteractorOutputProtocol?

    let walletConnect: WalletConnectDelegateInputProtocol

    init(walletConnect: WalletConnectDelegateInputProtocol) {
        self.walletConnect = walletConnect
    }

    private func provideSessions() {
        walletConnect.fetchSessions { _ in
        }
    }
}

extension WalletConnectSessionsInteractor: WalletConnectSessionsInteractorInputProtocol {
    func setup() {
        walletConnect.add(delegate: self)
    }

    func connect(uri: String) {
        walletConnect.connect(uri: uri)
    }
}

extension WalletConnectSessionsInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideSessions()
    }
}
