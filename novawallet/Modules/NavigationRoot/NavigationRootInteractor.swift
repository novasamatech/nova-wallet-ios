import UIKit
import Keystore_iOS

final class NavigationRootInteractor {
    weak var presenter: NavigationRootInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let walletSettings: SelectedWalletSettings
    let walletConnect: WalletConnectDelegateInputProtocol
    let walletNotificationService: WalletNotificationServiceProtocol

    init(
        eventCenter: EventCenterProtocol,
        walletSettings: SelectedWalletSettings,
        walletConnect: WalletConnectDelegateInputProtocol,
        walletNotificationService: WalletNotificationServiceProtocol
    ) {
        self.eventCenter = eventCenter
        self.walletSettings = walletSettings
        self.walletConnect = walletConnect
        self.walletNotificationService = walletNotificationService
    }
}

private extension NavigationRootInteractor {
    func provideSelectedWallet() {
        presenter?.didReceive(wallet: walletSettings.value)
    }

    func provideWalletConnectSessionsCount() {
        walletConnect.fetchSessions { [weak self] result in
            guard let selectedMetaAccount = self?.walletSettings.value else {
                return
            }

            switch result {
            case let .success(connections):
                let walletConnectSessions = connections.filter { connection in
                    connection.wallet?.identifier == selectedMetaAccount.identifier
                }
                self?.presenter?.didReceiveWalletConnect(sessionsCount: walletConnectSessions.count)
            case let .failure(error):
                self?.presenter?.didReceiveWalletConnect(error: .sessionsFetchFailed(error))
            }
        }
    }

    func handleWalletUpdate() {
        provideSelectedWallet()
        provideWalletConnectSessionsCount()
    }
}

extension NavigationRootInteractor: NavigationRootInteractorInputProtocol {
    func setup() {
        provideSelectedWallet()
        provideWalletConnectSessionsCount()

        eventCenter.add(observer: self, dispatchIn: .main)

        walletConnect.add(delegate: self)

        walletNotificationService.hasUpdatesObservable.addObserver(
            with: self,
            sendStateOnSubscription: true
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
        }
    }

    func connectWalletConnect(uri: String) {
        walletConnect.connect(uri: uri) { [weak self] error in
            if let error = error {
                self?.presenter?.didReceiveWalletConnect(error: .connectionFailed(error))
            }
        }
    }

    func retryFetchWalletConnectSessionsCount() {
        provideWalletConnectSessionsCount()
    }
}

extension NavigationRootInteractor: EventVisitorProtocol {
    func processChainAccountChanged(event _: ChainAccountChanged) {
        handleWalletUpdate()
    }

    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        handleWalletUpdate()
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        guard event.isSelectedWallet else {
            return
        }

        provideSelectedWallet()
    }
}

extension NavigationRootInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideWalletConnectSessionsCount()
    }

    func walletConnectDidChangeChains() {
        provideWalletConnectSessionsCount()
    }
}
