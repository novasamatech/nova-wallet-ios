import Foundation

final class MythosStakingDetailsWireframe: MythosStakingDetailsWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialDetails: MythosStakingDetails?
    ) {
        guard let stakeView = MythosStakingSetupViewFactory.createView(
            for: state,
            initialStakingDetails: initialDetails
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            stakeView.controller,
            animated: true
        )
    }

    func showUnstakeTokens(
        from _: ControllerBackedProtocol?,
        initialDetails _: MythosStakingDetails?
    ) {
        // TODO: Implement in a separate task
    }

    func showYourCollators(from _: ControllerBackedProtocol?) {
        // TODO: Implement in a separate task
    }
}
