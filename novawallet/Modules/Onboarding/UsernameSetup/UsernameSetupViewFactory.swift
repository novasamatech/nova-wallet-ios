import Foundation
import Foundation_iOS
import Keystore_iOS

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol? {
        let wireframe = UsernameSetupWireframe()
        return createView(for: wireframe)
    }

    static func createViewForAdding() -> UsernameSetupViewProtocol? {
        let wireframe = AddAccount.UsernameSetupWireframe()
        return createView(for: wireframe)
    }

    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.UsernameSetupWireframe()

        return createView(for: wireframe)
    }

    private static func createView(
        for wireframe: UsernameSetupWireframeProtocol
    ) -> UsernameSetupViewProtocol? {
        let presenter = UsernameSetupPresenter(wireframe: wireframe)

        let view = UserNameSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
