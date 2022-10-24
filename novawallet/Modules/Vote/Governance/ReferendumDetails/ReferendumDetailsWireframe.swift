import Foundation

final class ReferendumDetailsWireframe: ReferendumDetailsWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showFullDetails(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    ) {
        guard
            let fullDetailsView = ReferendumFullDetailsViewFactory.createView(
                state: state,
                referendum: referendum,
                actionDetails: actionDetails,
                identities: identities
            ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: fullDetailsView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showVote(from view: ReferendumDetailsViewProtocol?, referendum: ReferendumLocal) {
        guard
            let voteSetupView = ReferendumVoteSetupViewFactory.createView(
                for: state,
                referendum: referendum.index
            ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: voteSetupView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
