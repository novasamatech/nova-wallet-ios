import Foundation

final class LedgerNetworkSelectionWireframe: LedgerNetworkSelectionWireframeProtocol {
    let accountsStore: LedgerAccountsStore

    init(accountsStore: LedgerAccountsStore) {
        self.accountsStore = accountsStore
    }

    func showLedgerDiscovery(from _: LedgerNetworkSelectionViewProtocol?, chain _: ChainModel) {}

    func close(view: LedgerNetworkSelectionViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
