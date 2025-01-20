import Foundation
import SoraFoundation

struct MythosStakingSetupViewFactory {
    static func createView() -> CollatorStakingSetupViewProtocol? {
        let interactor = MythosStakingSetupInteractor()
        let wireframe = MythosStakingSetupWireframe()

        let presenter = MythosStakingSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = CollatorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: LocalizableResource { _ in "" },
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
