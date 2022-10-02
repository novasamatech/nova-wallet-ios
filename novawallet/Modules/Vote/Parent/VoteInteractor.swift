import Foundation

final class VoteInteractor {
    weak var presenter: VoteInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
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

        eventCenter.add(observer: self)
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
