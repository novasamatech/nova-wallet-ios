import Foundation

final class GenericLedgerDiscoverWireframe: LedgerDiscoverWireframeProtocol {
    let application: GenericLedgerSubstrateApplicationProtocol
    let flow: WalletCreationFlow

    init(application: GenericLedgerSubstrateApplicationProtocol, flow: WalletCreationFlow) {
        self.application = application
        self.flow = flow
    }

    func showAccountSelection(from view: ControllerBackedProtocol?, device: LedgerDeviceProtocol) {
        guard let accountsView = GenericLedgerAccountSelectionViewFactory.createView(
            application: application,
            device: device,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            accountsView.controller,
            animated: true
        )
    }
}
