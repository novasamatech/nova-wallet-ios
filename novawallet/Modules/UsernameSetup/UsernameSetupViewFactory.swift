import Foundation
import SoraFoundation
import SoraKeystore

final class UsernameSetupViewFactory: UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol? {
        let wireframe = UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor()
        return createView(for: wireframe, interactor: interactor)
    }

    static func createViewForAdding() -> UsernameSetupViewProtocol? {
        let wireframe = AddAccount.UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor()
        return createView(for: wireframe, interactor: interactor)
    }

    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor()

        return createView(for: wireframe, interactor: interactor)
    }

    private static func createView(
        for wireframe: UsernameSetupWireframeProtocol,
        interactor: UsernameSetupInteractor
    ) -> UsernameSetupViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let presenter = UsernameSetupPresenter()

        let view = UserNameSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return view
    }
}
