import UIKit

final class WalletConnectSessionDetailsInteractor {
    weak var presenter: WalletConnectSessionDetailsInteractorOutputProtocol?

    let walletConnect: WalletConnectDelegateInputProtocol
    let sessionId: String

    init(walletConnect: WalletConnectDelegateInputProtocol, sessionId: String) {
        self.walletConnect = walletConnect
        self.sessionId = sessionId
    }

    private func updateSession(for sessionId: String) {
        walletConnect.fetchSessions { [weak self] result in
            switch result {
            case let .success(sessions):
                if let session = sessions.first(where: { $0.sessionId == sessionId }) {
                    self?.presenter?.didUpdate(session: session)
                } else {
                    self?.presenter?.didDisconnect()
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .sessionUpdateFailed(error))
            }
        }
    }
}

extension WalletConnectSessionDetailsInteractor: WalletConnectSessionDetailsInteractorInputProtocol {
    func setup() {
        walletConnect.add(delegate: self)
    }

    func retrySessionUpdate() {
        updateSession(for: sessionId)
    }

    func disconnect() {
        walletConnect.disconnect(from: sessionId) { [weak self] optError in
            if let error = optError {
                self?.presenter?.didReceive(error: .disconnectionFailed(error))
            }
        }
    }
}

extension WalletConnectSessionDetailsInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        updateSession(for: sessionId)
    }
}
