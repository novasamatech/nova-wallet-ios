import Foundation

final class LedgerNetworkSelectionWireframe: LedgerNetworkSelectionWireframeProtocol {
    let accountsStore: LedgerAccountsStore
    let flow: WalletCreationFlow

    init(accountsStore: LedgerAccountsStore, flow: WalletCreationFlow) {
        self.accountsStore = accountsStore
        self.flow = flow
    }

    func showLedgerDiscovery(from view: LedgerNetworkSelectionViewProtocol?, chain: ChainModel) {
        guard let ledgerDiscovery = LedgerDiscoverViewFactory.createNewPairingView(
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
        guard let walletCreateView = LedgerWalletConfirmViewFactory.createLegacyView(
            with: accountsStore,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(walletCreateView.controller, animated: true)
    }
}
