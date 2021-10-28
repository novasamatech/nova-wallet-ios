import Foundation

final class WalletManagementWireframe: WalletManagementWireframeProtocol {
    func showWalletDetails(from _: WalletManagementViewProtocol?, metaAccount _: MetaAccountModel) {
        // TODO: Implement with new onboarding story
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
