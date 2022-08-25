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

    func showWalletCreate(from view: LedgerNetworkSelectionViewProtocol?) {
        guard let walletCreateView = LedgerWalletConfirmViewFactory.createView(with: accountsStore) else {
            return
        }

        view?.controller.navigationController?.pushViewController(walletCreateView.controller, animated: true)
    }
}
