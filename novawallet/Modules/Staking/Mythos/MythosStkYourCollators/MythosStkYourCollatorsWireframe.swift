import Foundation

final class MythosStkYourCollatorsWireframe: MythosStkYourCollatorsWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showCollatorInfo(
        from view: CollatorStkYourCollatorsViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) {
        guard let infoView = CollatorStakingInfoViewFactory.createMythosStakingView(
            for: state,
            collatorInfo: collatorInfo
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }

    func showStakeMore(
        from view: CollatorStkYourCollatorsViewProtocol?,
        initialDetails: MythosStakingDetails?
    ) {
        guard let stakeView = MythosStakingSetupViewFactory.createView(
            for: state,
            initialStakingDetails: initialDetails
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(stakeView.controller, animated: true)
    }

    func showUnstake(from view: CollatorStkYourCollatorsViewProtocol?) {
        guard let unstakeView = MythosStkUnstakeSetupViewFactory.createView(
            for: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(unstakeView.controller, animated: true)
    }
}
