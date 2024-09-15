import Foundation

final class TinderGovWireframe {
    let sharedState: GovernanceSharedState

    init(sharedState: GovernanceSharedState) {
        self.sharedState = sharedState
    }
}

// MARK: TinderGovWireframeProtocol

extension TinderGovWireframe: TinderGovWireframeProtocol {
    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showVotingList(
        from view: ControllerBackedProtocol?,
        metaId: MetaAccountModel.Id
    ) {
        guard let votingListView = SwipeGovVotingListViewFactory.createView(
            with: sharedState,
            metaId: metaId
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: votingListView.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showVoteSetup(
        from view: ControllerBackedProtocol?,
        referendum: ReferendumIdLocal,
        initData: ReferendumVotingInitData
    ) {
        guard let setupView = TinderGovSetupViewFactory.createView(
            for: sharedState,
            referendum: referendum,
            initData: initData
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: setupView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
