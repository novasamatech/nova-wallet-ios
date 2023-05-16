import Foundation
import SoraFoundation

struct StakingRewardFiltersViewFactory {
    static func createView() -> StakingRewardFiltersViewProtocol? {
        let interactor = StakingRewardFiltersInteractor()
        let wireframe = StakingRewardFiltersWireframe()

        let presenter = StakingRewardFiltersPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingRewardFiltersViewController(
            presenter: presenter,
            dateFormatter: DateFormatter.shortDate,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
