import Foundation
import SoraFoundation

struct AdvancedWalletViewFactory {
    static func createView(
        for secretSource: SecretSource,
        advancedSettings: AdvancedWalletSettings
    ) -> AdvancedWalletViewProtocol? {
        let wireframe = AdvancedWalletWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = AdvancedWalletPresenter(
            wireframe: wireframe,
            localizationManager: localizationManager,
            secretSource: secretSource,
            settings: advancedSettings
        )

        let view = AdvancedWalletViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view

        return view
    }
}
