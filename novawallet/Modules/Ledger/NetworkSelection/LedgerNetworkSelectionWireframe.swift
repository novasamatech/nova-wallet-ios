import Foundation

final class LedgerNetworkSelectionWireframe: LedgerNetworkSelectionWireframeProtocol {
    let accountsStore: LedgerAccountsStore

    init(accountsStore: LedgerAccountsStore) {
        self.accountsStore = accountsStore
    }

    func showLedgerDiscovery(from view: LedgerNetworkSelectionViewProtocol?, chain: ChainModel) {
        guard let ledgerDiscovery = LedgerDiscoverViewFactory.createView(
            chain: chain,
            accountsStore: accountsStore
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(ledgerDiscovery.controller, animated: true)
    }

    func close(view: LedgerNetworkSelectionViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
