import Foundation

final class SwipeGovWireframe {
    let sharedState: GovernanceSharedState
    let metaAccount: MetaAccountModel

    init(
        sharedState: GovernanceSharedState,
        metaAccount: MetaAccountModel
    ) {
        self.sharedState = sharedState
        self.metaAccount = metaAccount
    }
}

// MARK: SwipeGovWireframeProtocol

extension SwipeGovWireframe: SwipeGovWireframeProtocol {
    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showVotingList(
        from view: ControllerBackedProtocol?,
        metaId _: MetaAccountModel.Id
    ) {
        guard let votingListView = SwipeGovVotingListViewFactory.createView(
            with: sharedState,
            metaAccount: metaAccount
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
        initData: ReferendumVotingInitData
    ) {
        guard let setupView = SwipeGovSetupViewFactory.createView(
            for: sharedState,
            initData: initData
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: setupView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
