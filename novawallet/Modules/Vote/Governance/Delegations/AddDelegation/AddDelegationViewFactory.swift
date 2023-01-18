import Foundation
import SoraFoundation

struct AddDelegationViewFactory {
    static func createView(state: GovernanceSharedState) -> AddDelegationViewProtocol? {
        guard let stateOption = state.settings.value, let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }
        let chain = stateOption.chain
        let localizationManager = LocalizationManager.shared

        let interactor = AddDelegationInteractor(chain: chain)
        let wireframe = AddDelegationWireframe()

        let presenter = AddDelegationPresenter(interactor: interactor, wireframe: wireframe, localizationManager: localizationManager)

        let view = AddDelegationViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
