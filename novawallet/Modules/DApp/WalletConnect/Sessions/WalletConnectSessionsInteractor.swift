import UIKit

final class WalletConnectSessionsInteractor {
    weak var presenter: WalletConnectSessionsInteractorOutputProtocol?

    let walletConnect: WalletConnectDelegateInputProtocol

    init(walletConnect: WalletConnectDelegateInputProtocol) {
        self.walletConnect = walletConnect
    }

    private func provideSessions() {
        walletConnect.fetchSessions { [weak self] result in
            switch result {
            case let .success(sessions):
                self?.presenter?.didReceive(sessions: sessions)
            case let .failure(error):
                self?.presenter?.didReceive(error: .sessionsFetchFailed(error))
            }
        }
    }
}

extension WalletConnectSessionsInteractor: WalletConnectSessionsInteractorInputProtocol {
    func setup() {
        walletConnect.add(delegate: self)

        provideSessions()
    }

    func connect(uri: String) {
        walletConnect.connect(uri: uri)
    }

    func retrySessionsFetch() {
        provideSessions()
    }
}

extension WalletConnectSessionsInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideSessions()
    }
}
