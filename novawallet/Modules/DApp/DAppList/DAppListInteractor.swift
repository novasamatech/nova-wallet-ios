import UIKit

final class DAppListInteractor {
    weak var presenter: DAppListInteractorOutputProtocol!

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(walletSettings: SelectedWalletSettings, eventCenter: EventCenterProtocol) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
    }

    private func provideAccountId() {
        guard let wallet = walletSettings.value else {
            return
        }

        presenter.didReceive(accountIdResult: .success(wallet.substrateAccountId))
    }
}

extension DAppListInteractor: DAppListInteractorInputProtocol {
    func setup() {
        provideAccountId()

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension DAppListInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideAccountId()
    }
}
