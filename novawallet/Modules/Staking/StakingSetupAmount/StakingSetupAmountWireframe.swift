import Foundation

final class StakingSetupAmountWireframe: StakingSetupAmountWireframeProtocol {
    func showStakingTypeSelection(from view: ControllerBackedProtocol?) {
        guard let stakingTypeView = StakingTypeViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            stakingTypeView.controller,
            animated: true
        )
    }
}
