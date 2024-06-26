import Foundation

final class LedgerDiscoverWalletCreateWireframe: LedgerDiscoverWireframeProtocol {
    let accountsStore: LedgerAccountsStore
    let chain: ChainModel
    let application: LedgerApplication

    init(accountsStore: LedgerAccountsStore, application: LedgerApplication, chain: ChainModel) {
        self.accountsStore = accountsStore
        self.application = application
        self.chain = chain
    }

    func showAccountSelection(from view: ControllerBackedProtocol?, device: LedgerDeviceProtocol) {
        guard let confirmView = LedgerAccountConfirmationViewFactory.createNewWalletView(
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

final class LedgerDiscoverAccountAddWireframe: LedgerDiscoverWireframeProtocol {
    let wallet: MetaAccountModel
    let application: LedgerApplication
    let chain: ChainModel

    init(wallet: MetaAccountModel, application: LedgerApplication, chain: ChainModel) {
        self.wallet = wallet
        self.application = application
        self.chain = chain
    }

    func showAccountSelection(from view: ControllerBackedProtocol?, device: LedgerDeviceProtocol) {
        guard let confirmView = LedgerAccountConfirmationViewFactory.createAddAccountView(
            wallet: wallet,
            chain: chain,
            device: device,
            application: application
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
