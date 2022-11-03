import Foundation

final class GovernanceUnlockSetupWireframe: GovernanceUnlockSetupWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showConfirm(
        from view: GovernanceUnlockSetupViewProtocol?,
        votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>,
        schedule: GovernanceUnlockSchedule,
        blockNumber: BlockNumber
    ) {
        guard let confirmView = GovernanceUnlockConfirmViewFactory.createView(
            for: state,
            votingResult: votingResult,
            schedule: schedule,
            blockNumber: blockNumber
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
