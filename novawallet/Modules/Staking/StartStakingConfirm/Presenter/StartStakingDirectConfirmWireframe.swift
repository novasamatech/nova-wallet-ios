import Foundation

final class StartStakingDirectConfirmWireframe: StartStakingConfirmWireframe,
    StartStakingDirectConfirmWireframeProtocol {
    let stakingState: RelaychainStartStakingStateProtocol

    init(stakingState: RelaychainStartStakingStateProtocol) {
        self.stakingState = stakingState
    }

    func showSelectedValidators(from view: StartStakingConfirmViewProtocol?, validators: PreparedValidators) {
        guard
            let listView = StaticValidatorListViewFactory.createView(
                validatorList: validators,
                stakingState: stakingState
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(listView.controller, animated: true)
    }
}
