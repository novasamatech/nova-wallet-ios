import Foundation
import RobinHood

final class VoteInteractor {
    weak var presenter: VoteInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let walletNotificationService: WalletNotificationServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        walletNotificationService: WalletNotificationServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.walletNotificationService = walletNotificationService
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

        walletNotificationService.hasUpdatesObservable.addObserver(
            with: self,
            sendStateOnSubscription: true
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
        }
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
