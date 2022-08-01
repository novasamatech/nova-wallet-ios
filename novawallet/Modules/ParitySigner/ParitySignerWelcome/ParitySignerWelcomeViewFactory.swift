import Foundation
import SoraFoundation

struct ParitySignerWelcomeViewFactory {
    static func createView() -> ParitySignerWelcomeViewProtocol? {
        let wireframe = ParitySignerWelcomeWireframe()

        let presenter = ParitySignerWelcomePresenter(wireframe: wireframe)

        let view = ParitySignerWelcomeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
