import Foundation

final class GiftClaimWireframe: GiftClaimWireframeProtocol {
    func showManageWallets(from view: (any ControllerBackedProtocol)?) {
        guard let manageWalletsView = WalletManageViewFactory.createViewForAdding() else {
            return
        }
        
        let navigationController = NovaNavigationController(
            rootViewController: manageWalletsView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}
