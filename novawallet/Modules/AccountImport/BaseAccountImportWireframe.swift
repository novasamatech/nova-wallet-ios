import Foundation

class BaseAccountImportWireframe: BaseAccountImportWireframeProtocol {
    func showModifiableAdvancedSettings(
        from view: AccountImportViewProtocol?,
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

    func showReadonlyAdvancedSettings(
        from view: AccountImportViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    ) {
        guard let advancedView = AdvancedWalletViewFactory.createReadonlyView(
            for: secretSource,
            advancedSettings: settings
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
