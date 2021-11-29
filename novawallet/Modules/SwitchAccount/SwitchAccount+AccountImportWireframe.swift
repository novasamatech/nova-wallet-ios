import Foundation

extension SwitchAccount {
    final class AccountImportWireframe: AccountImportWireframeProtocol {
        func proceed(from view: AccountImportViewProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }

        func showAdvancedSettings(
            from view: AccountImportViewProtocol?,
            secretSource: SecretSource,
            settings: AdvancedWalletSettings
        ) {
            guard let advancedView = AdvancedWalletViewFactory.createView(
                for: secretSource,
                advancedSettings: settings
            ) else {
                return
            }

            let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

            view?.controller.present(navigationController, animated: true)
        }
    }
}
