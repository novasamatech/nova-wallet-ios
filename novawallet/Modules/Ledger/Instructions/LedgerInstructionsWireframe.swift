import Foundation

final class LedgerInstructionsWireframe: LedgerInstructionsWireframeProtocol {
    func showNetworkSelection(from view: LedgerInstructionsViewProtocol?) {
        guard let networkSelectionView = LedgerNetworkSelectionViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            networkSelectionView.controller,
            animated: true
        )
    }
}
