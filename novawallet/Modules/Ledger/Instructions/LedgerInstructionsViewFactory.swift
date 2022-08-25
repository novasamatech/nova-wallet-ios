import Foundation
import SoraFoundation

struct LedgerInstructionsViewFactory {
    static func createView() -> LedgerInstructionsViewProtocol? {
        let wireframe = LedgerInstructionsWireframe()

        let presenter = LedgerInstructionsPresenter(
            wireframe: wireframe,
            applicationConfig: ApplicationConfig.shared
        )

        let view = LedgerInstructionsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
