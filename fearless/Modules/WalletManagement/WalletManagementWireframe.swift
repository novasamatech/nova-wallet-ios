import Foundation

final class WalletManagementWireframe: WalletManagementWireframeProtocol {
    func showWalletDetails(from view: WalletManagementViewProtocol?, metaAccount: MetaAccountModel) {
        guard let chainManagementView = AccountManagementViewFactory.createView(for: metaAccount.identifier) else {
            return
        }

        chainManagementView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            chainManagementView.controller,
            animated: true
        )
    }

    func showAddWallet(from view: WalletManagementViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }

    func complete(from view: WalletManagementViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
