import Foundation

final class LedgerDiscoverWireframe: LedgerDiscoverWireframeProtocol {
    let accountsStore: LedgerAccountsStore
    let application: LedgerApplication

    init(accountsStore: LedgerAccountsStore, application: LedgerApplication) {
        self.accountsStore = accountsStore
        self.application = application
    }

    func showAccountSelection(from _: LedgerDiscoverViewProtocol?, chain: ChainModel, deviceId: UUID) {
        guard let confirmView = LedgerAccountConfirmationViewFactory.createView(
            chain: chain,
            deviceId: deviceId,
            application: application,
            accountsStore: accountsStore
        ) else {
            return
        }

        confirmView.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
