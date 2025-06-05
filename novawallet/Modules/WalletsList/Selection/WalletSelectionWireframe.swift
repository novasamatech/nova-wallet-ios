import UIKit
import UIKit_iOS

final class WalletSelectionWireframe: WalletsListWireframe, WalletSelectionWireframeProtocol {
    func close(view: WalletsListViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showSettings(from view: WalletsListViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            self.openWalletManage()
        }
    }

    private func openWalletManage() {
        guard let manageView = WalletManageViewFactory.createViewForSwitching() else {
            return
        }

        guard let tabBarController = UIApplication.shared.tabBarController else {
            return
        }

        let navigationController = tabBarController.selectedViewController as? UINavigationController
        navigationController?.popToRootViewController(animated: false)

        manageView.controller.hidesBottomBarWhenPushed = true

        navigationController?.pushViewController(manageView.controller, animated: true)
    }

    func showDelegatesUpdates(
        from view: ControllerBackedProtocol?,
        initWallets: [ManagedMetaAccountModel]
    ) {
        guard let proxiedsUpdatesView = DelegatedAccountsUpdateViewFactory.createView(
            initWallets: initWallets
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        proxiedsUpdatesView.controller.modalTransitioningFactory = factory
        proxiedsUpdatesView.controller.modalPresentationStyle = .custom

        view?.controller.present(proxiedsUpdatesView.controller, animated: true)
    }
}
