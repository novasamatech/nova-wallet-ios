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

        let navigationController = ImportantFlowViewFactory.createNavigation(from: stakeView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showUnstakeTokens(from view: ControllerBackedProtocol?) {
        guard let unstakeView = MythosStkUnstakeSetupViewFactory.createView(for: state) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unstakeView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showYourCollators(from _: ControllerBackedProtocol?) {
        // TODO: Implement in a separate task
    }

    func showRedeemTokens(from _: ControllerBackedProtocol?) {
        // TODO: Implement in a separate task
    }
}
