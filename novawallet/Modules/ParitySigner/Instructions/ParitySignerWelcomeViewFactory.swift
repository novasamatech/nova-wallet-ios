import Foundation
import Foundation_iOS

struct ParitySignerWelcomeViewFactory {
    static func createOnboardingView(with type: ParitySignerType) -> ParitySignerWelcomeViewProtocol? {
        createView(with: type, wireframe: ParitySignerWelcomeWireframe())
    }

    static func createAddAccountView(with type: ParitySignerType) -> ParitySignerWelcomeViewProtocol? {
        createView(with: type, wireframe: AddAccount.ParitySignerWelcomeWireframe())
    }

    static func createSwitchAccountView(with type: ParitySignerType) -> ParitySignerWelcomeViewProtocol? {
        createView(with: type, wireframe: SwitchAccount.ParitySignerWelcomeWireframe())
    }

    private static func createView(
        with type: ParitySignerType,
        wireframe: ParitySignerWelcomeWireframeProtocol
    ) -> ParitySignerWelcomeViewProtocol? {
        let presenter = ParitySignerWelcomePresenter(wireframe: wireframe, type: type)

        let view = ParitySignerWelcomeViewController(
            presenter: presenter,
            type: type,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
