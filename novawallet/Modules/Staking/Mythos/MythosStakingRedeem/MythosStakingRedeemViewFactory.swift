import Foundation
import SoraFoundation

struct MythosStakingRedeemViewFactory {
    static func createView() -> CollatorStakingRedeemViewProtocol? {
        let interactor = MythosStakingRedeemInteractor()
        let wireframe = MythosStakingRedeemWireframe()

        let presenter = MythosStakingRedeemPresenter(interactor: interactor, wireframe: wireframe)

        let view = CollatorStakingRedeemViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
