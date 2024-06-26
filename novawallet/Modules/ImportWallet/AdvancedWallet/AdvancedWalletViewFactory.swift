import Foundation
import SoraFoundation

struct AdvancedWalletViewFactory {
    static func createView(
        for secretSource: SecretSource,
        advancedSettings: AdvancedWalletSettings,
        delegate: AdvancedWalletSettingsDelegate
    ) -> AdvancedWalletViewProtocol? {
        let wireframe = AdvancedWalletWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = AdvancedWalletPresenter(
            wireframe: wireframe,
            localizationManager: localizationManager,
            secretSource: secretSource,
            settings: advancedSettings,
            delegate: delegate
        )

        let view = AdvancedWalletViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            readonly: false
        )

        presenter.view = view

        return view
    }

    static func createReadonlyView(
        for secretSource: SecretSource,
        advancedSettings: AdvancedWalletSettings
    ) -> AdvancedWalletViewProtocol? {
        let wireframe = AdvancedWalletWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = AdvancedWalletPresenter(
            wireframe: wireframe,
            localizationManager: localizationManager,
            secretSource: secretSource,
            settings: advancedSettings,
            delegate: nil
        )

        let view = AdvancedWalletViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            readonly: true
        )

        presenter.view = view

        return view
    }
}
