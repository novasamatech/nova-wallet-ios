import Foundation

final class AnalyticsValidatorsWireframe: AnalyticsValidatorsWireframeProtocol {
    let state: StakingSharedState

    init(state: StakingSharedState) {
        self.state = state
    }

    func showValidatorInfo(address: AccountAddress, view: ControllerBackedProtocol?) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: address,
            state: state
        ) else { return }
        let navigationController = FearlessNavigationController(rootViewController: validatorInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
