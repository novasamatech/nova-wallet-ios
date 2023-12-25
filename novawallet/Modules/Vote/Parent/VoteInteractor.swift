import Foundation
import RobinHood

final class VoteInteractor {
    weak var presenter: VoteInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let proxyNotificationService: WalletNotificationServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        proxyNotificationService: WalletNotificationServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.proxyNotificationService = proxyNotificationService
    }

    private func provideSelectedWallet() {
        guard let selectedWallet = walletSettings.value else {
            return
        }

        presenter?.didReceiveWallet(selectedWallet)
    }
}

extension VoteInteractor: VoteInteractorInputProtocol {
    func setup() {
        provideSelectedWallet()

        eventCenter.add(observer: self, dispatchIn: .main)

        proxyNotificationService.hasUpdatesObservable.addObserver(with: self) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
        }
        proxyNotificationService.setup()
    }
}

extension VoteInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideSelectedWallet()
    }

    func processChainAccountChanged(event _: ChainAccountChanged) {
        provideSelectedWallet()
    }
}
