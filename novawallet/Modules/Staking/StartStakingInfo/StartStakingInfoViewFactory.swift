import Foundation
import SoraFoundation

struct StartStakingInfoViewFactory {
    static func createView() -> StartStakingInfoViewProtocol? {
        let interactor = StartStakingInfoInteractor()
        let wireframe = StartStakingInfoWireframe()

        let presenter = StartStakingInfoPresenter(interactor: interactor, wireframe: wireframe, startStakingViewModelFactory: StartStakingViewModelFactory())

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
