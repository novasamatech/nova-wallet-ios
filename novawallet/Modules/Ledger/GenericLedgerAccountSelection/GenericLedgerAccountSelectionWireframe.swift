import Foundation

final class GenericLedgerAccountSelectionWireframe: GenericLedgerAccountSelectionWireframeProtocol {
    let flow: WalletCreationFlow
    let application: GenericLedgerSubstrateApplicationProtocol
    let device: LedgerDeviceProtocol

    init(
        flow: WalletCreationFlow,
        application: GenericLedgerSubstrateApplicationProtocol,
        device: LedgerDeviceProtocol
    ) {
        self.flow = flow
        self.application = application
        self.device = device
    }

    func showWalletCreate(from view: GenericLedgerAccountSelectionViewProtocol?, index: UInt32) {
        guard let accountsView = GenericLedgerWalletViewFactory.createView(
            for: application,
            device: device,
            index: index,
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
