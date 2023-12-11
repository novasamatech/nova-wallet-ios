import UIKit
import SoraUI

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

        guard let tabBarController = UIApplication.shared
            .delegate?.window??.rootViewController as? UITabBarController
        else {
            return
        }

        let navigationController = tabBarController.selectedViewController as? UINavigationController
        navigationController?.popToRootViewController(animated: false)

        manageView.controller.hidesBottomBarWhenPushed = true

        navigationController?.pushViewController(manageView.controller, animated: true)
    }

    func showDelegateUpdates(
        from view: ControllerBackedProtocol?,
        initWallets: [ManagedMetaAccountModel],
        completion: @escaping () -> Void
    ) {
        guard let delegateUpdatesView = DelegatedAccountsUpdateViewFactory.createView(
            initWallets: initWallets,
            completion: completion
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        delegateUpdatesView.controller.modalTransitioningFactory = factory
        delegateUpdatesView.controller.modalPresentationStyle = .custom

        view?.controller.present(delegateUpdatesView.controller, animated: true)
    }
}
