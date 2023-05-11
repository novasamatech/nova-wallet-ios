import Foundation
import SoraFoundation

struct StackingRewardFiltersViewFactory {
    static func createView() -> StackingRewardFiltersViewProtocol? {
        let interactor = StackingRewardFiltersInteractor()
        let wireframe = StackingRewardFiltersWireframe()

        let presenter = StackingRewardFiltersPresenter(interactor: interactor, wireframe: wireframe)

        let view = StackingRewardFiltersViewController(
            presenter: presenter,
            dateFormatter: DateFormatter.shortDate,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
