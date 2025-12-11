import Foundation
import Foundation_iOS

struct PVWelcomeViewFactory {
    static func createOnboardingView(with type: ParitySignerType) -> PVWelcomeViewProtocol? {
        createView(with: type, wireframe: PVWelcomeWireframe())
    }

    static func createAddAccountView(with type: ParitySignerType) -> PVWelcomeViewProtocol? {
        createView(with: type, wireframe: AddAccount.PVWelcomeWireframe())
    }

    static func createSwitchAccountView(with type: ParitySignerType) -> PVWelcomeViewProtocol? {
        createView(with: type, wireframe: SwitchAccount.PVWelcomeWireframe())
    }

    private static func createView(
        with type: ParitySignerType,
        wireframe: PVWelcomeWireframeProtocol
    ) -> PVWelcomeViewProtocol? {
        let presenter = PVWelcomePresenter(wireframe: wireframe, type: type)

        let view = PVWelcomeViewController(
            presenter: presenter,
            type: type,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
