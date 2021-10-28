import Foundation

extension SwitchAccount {
    final class WalletManagementWireframe: WalletManagementWireframeProtocol {
        func showWalletDetails(from _: WalletManagementViewProtocol?, metaAccount _: MetaAccountModel) {
            // TODO: Implement when new onboarding process done
        }

        func showAddWallet(from view: WalletManagementViewProtocol?) {
            guard let onboarding = OnboardingMainViewFactory.createViewForAccountSwitch() else {
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

            navigationController.popToRootViewController(animated: true)
        }
    }
}
