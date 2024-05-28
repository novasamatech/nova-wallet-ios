import Foundation

extension SwitchAccount {
    final class WalletManageWireframe: WalletBaseManageWireframe, WalletManageWireframeProtocol {
        func showWalletDetails(from view: WalletManageViewProtocol?, metaAccount: MetaAccountModel) {
            guard let chainManagementView = AccountManagementViewFactory.createView(for: metaAccount.identifier) else {
                return
            }

            chainManagementView.controller.hidesBottomBarWhenPushed = true

            view?.controller.navigationController?.pushViewController(
                chainManagementView.controller,
                animated: true
            )
        }

        func showCreateWallet(from view: WalletManageViewProtocol?) {
            guard let onboarding = UsernameSetupViewFactory.createViewForSwitch() else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(onboarding.controller, animated: true)
            }
        }

        func showImportWallet(from _: WalletManageViewProtocol?) {
            // TODO: add for switch
        }
    }
}
