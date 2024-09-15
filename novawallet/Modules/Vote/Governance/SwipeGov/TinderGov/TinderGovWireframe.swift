import Foundation

final class TinderGovWireframe {
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

// MARK: TinderGovWireframeProtocol

extension TinderGovWireframe: TinderGovWireframeProtocol {
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
