import Foundation

extension SwitchAccount {
    final class WalletManageWireframe: WalletsListWireframe, WalletManageWireframeProtocol {
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

        func showAddWallet(from view: WalletManageViewProtocol?) {
            guard let onboarding = OnboardingMainViewFactory.createViewForAccountSwitch() else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(onboarding.controller, animated: true)
            }
        }
    }
}
