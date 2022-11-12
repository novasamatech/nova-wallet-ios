import Foundation

final class ReferendumVoteSetupWireframe: ReferendumVoteSetupWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showConfirmation(
        from view: ReferendumVoteSetupViewProtocol?,
        vote: ReferendumNewVote,
        initData: ReferendumVotingInitData
    ) {
        guard let confirmView = ReferendumVoteConfirmViewFactory.createView(
            for: state,
            newVote: vote,
            initData: initData
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
