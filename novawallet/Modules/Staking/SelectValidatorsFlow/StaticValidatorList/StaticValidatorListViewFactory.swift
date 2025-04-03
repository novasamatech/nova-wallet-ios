import Foundation
import Foundation_iOS

struct StaticValidatorListViewFactory {
    static func createView(
        validatorList: PreparedValidators,
        stakingState: RelaychainStartStakingStateProtocol
    ) -> StaticValidatorListViewProtocol? {
        let viewModelFactory = SelectedValidatorListViewModelFactory()
        let wireframe = StaticValidatorListWireframe(stakingState: stakingState)

        let selectedValidators = validatorList.targets

        let presenter = StaticValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            selectedValidatorList: selectedValidators,
            maxTargets: validatorList.maxTargets,
            localizationManager: LocalizationManager.shared
        )

        let view = StaticValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: validatorList.maxTargets,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
