import Foundation
import SoraFoundation

struct ParitySignerWelcomeViewFactory {
    static func createOnboardingView() -> ParitySignerWelcomeViewProtocol? {
        createView(wireframe: ParitySignerWelcomeWireframe())
    }

    static func createAddAccountView() -> ParitySignerWelcomeViewProtocol? {
        createView(wireframe: AddAccount.ParitySignerWelcomeWireframe())
    }

    static func createSwitchAccountView() -> ParitySignerWelcomeViewProtocol? {
        createView(wireframe: SwitchAccount.ParitySignerWelcomeWireframe())
    }

    private static func createView(
        wireframe: ParitySignerWelcomeWireframeProtocol
    ) -> ParitySignerWelcomeViewProtocol? {
        let presenter = ParitySignerWelcomePresenter(wireframe: wireframe)

        let view = ParitySignerWelcomeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
