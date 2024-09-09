import Foundation
import SoraFoundation

struct TinderGovViewFactory {
    static func createView(with referendums: [ReferendumLocal]) -> TinderGovViewProtocol? {
        let wireframe = TinderGovWireframe()
        let interactor = TinderGovInteractor(referendums: referendums)

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = TinderGovViewModelFactory()

        let presenter = TinderGovPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = TinderGovViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
