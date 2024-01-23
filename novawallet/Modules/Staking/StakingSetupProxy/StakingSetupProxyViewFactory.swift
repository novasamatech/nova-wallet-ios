import Foundation
import SoraFoundation

struct StakingSetupProxyViewFactory {
    static func createView() -> StakingSetupProxyViewProtocol? {
        let interactor = StakingSetupProxyInteractor()
        let wireframe = StakingSetupProxyWireframe()

        let presenter = StakingSetupProxyPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingSetupProxyViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
