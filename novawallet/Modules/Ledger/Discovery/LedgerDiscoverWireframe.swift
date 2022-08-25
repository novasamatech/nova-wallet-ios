import Foundation

final class LedgerDiscoverWireframe: LedgerDiscoverWireframeProtocol {
    let accountsStore: LedgerAccountsStore
    let application: LedgerApplication

    init(accountsStore: LedgerAccountsStore, application: LedgerApplication) {
        self.accountsStore = accountsStore
        self.application = application
    }

    func showAccountSelection(from view: ControllerBackedProtocol?, chain: ChainModel, device: LedgerDeviceProtocol) {
        guard let confirmView = LedgerAccountConfirmationViewFactory.createView(
            chain: chain,
            device: device,
            application: application,
            accountsStore: accountsStore
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
