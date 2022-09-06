import UIKit

final class LedgerNetworkSelectionInteractor {
    weak var presenter: LedgerNetworkSelectionInteractorOutputProtocol?

    let accountsStore: LedgerAccountsStore

    init(accountsStore: LedgerAccountsStore) {
        self.accountsStore = accountsStore
    }
}

extension LedgerNetworkSelectionInteractor: LedgerNetworkSelectionInteractorInputProtocol {
    func setup() {
        accountsStore.addObserver(with: self) { [weak self] _, newAccounts in
            self?.presenter?.didReceive(chainAccounts: newAccounts)
        }

        accountsStore.setup()
    }
}
