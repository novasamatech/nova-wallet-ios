import Foundation

final class YourValidatorListWireframe: YourValidatorListWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: YourValidatorListViewProtocol?
    ) {
        guard let nextView = ValidatorInfoViewFactory.createView(with: validatorInfo, state: state) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }

    func proceedToSelectValidatorsStart(
        from view: YourValidatorListViewProtocol?,
        existingBonding: ExistingBonding
    ) {
        guard let nextView = SelectValidatorsStartViewFactory.createChangeYourValidatorsView(
            with: existingBonding,
            stakingState: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            nextView.controller,
            animated: true
        )
    }
}
