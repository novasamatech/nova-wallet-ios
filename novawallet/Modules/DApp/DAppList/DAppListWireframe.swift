import Foundation

final class DAppListWireframe: DAppListWireframeProtocol {
    func showWalletSelection(from view: DAppListViewProtocol?) {
        guard let accountsView = WalletManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(accountsView.controller, animated: true)
    }

    func showSearch(from view: DAppListViewProtocol?) {
        guard let searchView = DAppSearchViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: searchView.controller)
        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
