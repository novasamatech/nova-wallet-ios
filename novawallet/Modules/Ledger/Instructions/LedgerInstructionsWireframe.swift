import Foundation

final class LedgerInstructionsWireframe: LedgerInstructionsWireframeProtocol {
    let flow: WalletCreationFlow

    init(flow: WalletCreationFlow) {
        self.flow = flow
    }

    func showNetworkSelection(from view: LedgerInstructionsViewProtocol?) {
        guard let networkSelectionView = LedgerNetworkSelectionViewFactory.createView(for: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            networkSelectionView.controller,
            animated: true
        )
    }
}
