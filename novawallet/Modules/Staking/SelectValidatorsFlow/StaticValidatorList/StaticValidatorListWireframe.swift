import Foundation

class StaticValidatorListWireframe: StaticValidatorListWireframeProtocol {
    let stakingState: RelaychainStartStakingStateProtocol

    init(stakingState: RelaychainStartStakingStateProtocol) {
        self.stakingState = stakingState
    }

    func present(_ validatorInfo: ValidatorInfoProtocol, from view: ControllerBackedProtocol?) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: validatorInfo,
            chainAsset: stakingState.chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }
}
