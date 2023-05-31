import UIKit

final class WalletConnectSessionsInteractor {
    typealias Filter = (WalletConnectSession) -> Bool
    weak var presenter: WalletConnectSessionsInteractorOutputProtocol?

    let walletConnect: WalletConnectDelegateInputProtocol
    let sessionFilter: Filter?

    init(
        walletConnect: WalletConnectDelegateInputProtocol,
        sessionFilter: Filter? = nil
    ) {
        self.walletConnect = walletConnect
        self.sessionFilter = sessionFilter
    }

    private func provideSessions() {
        walletConnect.fetchSessions { [weak self] result in
            switch result {
            case let .success(sessions):
                let filteredSessions = self?.sessionFilter.map { sessions.filter($0) } ?? sessions
                self?.presenter?.didReceive(sessions: filteredSessions)
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
        walletConnect.connect(uri: uri) { [weak self] optError in
            if let error = optError {
                self?.presenter?.didReceive(error: .connectionFailed(error))
            }
        }
    }

    func retrySessionsFetch() {
        provideSessions()
    }
}

extension WalletConnectSessionsInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideSessions()
    }

    func walletConnectDidChangeChains() {
        provideSessions()
    }
}
