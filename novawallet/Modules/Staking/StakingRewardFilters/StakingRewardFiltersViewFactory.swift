import Foundation
import SoraFoundation

struct StakingRewardFiltersViewFactory {
    static func createView(
        initialState: StakingRewardFiltersPeriod?,
        delegate: StakingRewardFiltersDelegate
    ) -> StakingRewardFiltersViewProtocol? {
        let wireframe = StakingRewardFiltersWireframe()

        let presenter = StakingRewardFiltersPresenter(
            initialState: initialState,
            delegate: delegate,
            wireframe: wireframe
        )

        let view = StakingRewardFiltersViewController(
            presenter: presenter,
            dateFormatter: DateFormatter.shortDate,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
