import Foundation

final class DAppListWireframe: DAppListWireframeProtocol {
    func showWalletSelection(from view: DAppListViewProtocol?) {
        guard let accountsView = WalletManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(accountsView.controller, animated: true)
    }
}
