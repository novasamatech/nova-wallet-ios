import Foundation

final class SwipeGovWireframe {
    let sharedState: GovernanceSharedState

    init(sharedState: GovernanceSharedState) {
        self.sharedState = sharedState
    }
}

// MARK: SwipeGovWireframeProtocol

extension SwipeGovWireframe: SwipeGovWireframeProtocol {
    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showVotingList(from view: ControllerBackedProtocol?) {
        guard let votingListView = SwipeGovVotingListViewFactory.createView(with: sharedState) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: votingListView.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showVoteSetup(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData,
        newVotingPowerClosure: VotingPowerLocalSetClosure?
    ) {
        guard let setupView = SwipeGovSetupViewFactory.createView(
            for: sharedState,
            initData: initData,
            newVotingPowerClosure: newVotingPowerClosure
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: setupView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        initData: ReferendumDetailsInitData
    ) {
        guard let detailsView = SwipeGovReferendumDetailsViewFactory.createView(
            for: sharedState,
            initData: initData
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: detailsView.controller
        )

        view?.controller.present(navigationController, animated: true)
    }
}
