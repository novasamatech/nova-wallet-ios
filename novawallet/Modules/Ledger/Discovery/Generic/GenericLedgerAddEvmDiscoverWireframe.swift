import Foundation

final class GenericLedgerAddEvmDiscoverWireframe: LedgerDiscoverWireframeProtocol {
    let application: GenericLedgerPolkadotApplicationProtocol
    let wallet: MetaAccountModel

    init(application: GenericLedgerPolkadotApplicationProtocol, wallet: MetaAccountModel) {
        self.application = application
        self.wallet = wallet
    }

    func showAccountSelection(from view: ControllerBackedProtocol?, device: LedgerDeviceProtocol) {
        guard let accountsView = GenericLedgerAddEvmViewFactory.createView(
            wallet: wallet,
            application: application,
            device: device
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            accountsView.controller,
            animated: true
        )
    }
}
