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

//    @available(iOS, obsoleted: 10, message: "Network selection functionality does not longer exist")
    static func createViewForSwitch() -> UsernameSetupViewProtocol? {
        let wireframe = SwitchAccount.UsernameSetupWireframe()
        let interactor = UsernameSetupInteractor()

        return createView(for: wireframe, interactor: interactor)
    }

    private static func createView(
        for wireframe: UsernameSetupWireframeProtocol,
        interactor: UsernameSetupInteractor
    ) -> UsernameSetupViewProtocol? {
        let view = UsernameSetupViewController(nib: R.nib.usernameSetupViewController)
        let presenter = UsernameSetupPresenter()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared
        presenter.localizationManager = LocalizationManager.shared

        return view
    }
}
