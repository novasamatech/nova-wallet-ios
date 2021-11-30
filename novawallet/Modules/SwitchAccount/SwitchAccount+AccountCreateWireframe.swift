import Foundation

extension SwitchAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func showAdvancedSettings(
            from view: AccountCreateViewProtocol?,
            secretSource: SecretSource,
            settings: AdvancedWalletSettings,
            delegate: AdvancedWalletSettingsDelegate
        ) {
            guard let advancedView = AdvancedWalletViewFactory.createView(
                for: secretSource,
                advancedSettings: settings,
                delegate: delegate
            ) else {
                return
            }

            let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

            view?.controller.present(navigationController, animated: true)
        }

        func confirm(
            from view: AccountCreateViewProtocol?,
            request: MetaAccountCreationRequest,
            metadata: MetaAccountCreationMetadata
        ) {
            guard let accountConfirmation = AccountConfirmViewFactory
                .createViewForSwitch(request: request, metadata: metadata)?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(accountConfirmation, animated: true)
            }
        }
    }
}
