import Foundation

final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe,
    StartStakingInfoSubtensorWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let setupAmount = SubtensorStakingSetupViewFactory.createView(
            for: state,
            initialPosition: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupAmount.controller,
            animated: true
        )
    }
}
