import Foundation

class RecommendedValidatorListWireframe: RecommendedValidatorListWireframeProtocol {
    let stakingState: StakingSharedState

    init(stakingState: StakingSharedState) {
        self.stakingState = stakingState
    }

    func proceed(
        from _: RecommendedValidatorListViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func present(
        _ validatorInfo: SelectedValidatorInfo,
        from view: RecommendedValidatorListViewProtocol?
    ) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: validatorInfo,
            state: stakingState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorInfoView.controller, animated: true)
    }
}
