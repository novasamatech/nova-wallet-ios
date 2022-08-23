import Foundation

final class LedgerAccountConfirmationWireframe: LedgerAccountConfirmationWireframeProtocol {
    func complete(on view: LedgerAccountConfirmationViewProtocol?) {
        guard
            let navigationController = view?.controller.navigationController,
            let networkSelectionView = navigationController.viewControllers.first(
                where: { $0 is LedgerNetworkSelectionViewProtocol }
            ) else {
            return
        }

        navigationController.popToViewController(networkSelectionView, animated: true)
    }
}
