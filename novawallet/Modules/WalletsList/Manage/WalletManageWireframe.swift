import Foundation

class WalletBaseManageWireframe: WalletsListWireframe {
    func showOnboarding(from _: WalletManageViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForOnboarding() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: onboarding.controller)

        let rootAnimator = RootControllerAnimationCoordinator()
        rootAnimator.animateTransition(to: navigationController)
    }
}

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

    func showAddWallet(from view: WalletManageViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }
}
