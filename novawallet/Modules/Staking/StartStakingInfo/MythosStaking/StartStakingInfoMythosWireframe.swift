import Foundation

final class StartStakingInfoMythosWireframe: StartStakingInfoWireframe {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let setupAmount = MythosStakingSetupViewFactory.createView(
            for: state,
            initialStakingDetails: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupAmount.controller,
            animated: true
        )
    }
}
