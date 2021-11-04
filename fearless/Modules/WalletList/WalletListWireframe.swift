import Foundation

final class WalletListWireframe: WalletListWireframeProtocol {
    func showWalletList(from view: WalletListViewProtocol?) {
        guard let accountManagement = WalletManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountManagement.controller,
            animated: true
        )
    }
}
