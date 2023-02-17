import Foundation
import SoraUI

final class GovernanceDelegateInfoWireframe: GovernanceDelegateInfoWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showFullDescription(
        from view: GovernanceDelegateInfoViewProtocol?,
        name: String,
        longDescription: String
    ) {
        guard let view = view,
              let navigationController = view.controller.navigationController else {
            return
        }

        let state = DelegateInfoDetailsState(name: name, longDescription: longDescription)
        let delegateInfoDetailsViewController = DelegateInfoDetailsViewFactory.createView(state: state)

        navigationController.pushViewController(
            delegateInfoDetailsViewController.controller,
            animated: true
        )
    }

    func showDelegations(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress
    ) {
        guard let delegationListView = DelegationListViewFactory.createView(
            accountAddress: delegateAddress,
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            delegationListView.controller,
            animated: true
        )
    }

    func showRecentVotes(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress,
        delegateName: String?
    ) {
        guard let votedReferendaView = DelegateVotedReferendaViewFactory.createRecentVotesView(
            state: state,
            delegateAddress: delegateAddress,
            delegateName: delegateName
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            votedReferendaView.controller,
            animated: true
        )
    }

    func showAllVotes(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress,
        delegateName: String?
    ) {
        guard let votedReferendaView = DelegateVotedReferendaViewFactory.createAllVotesView(
            state: state,
            delegateAddress: delegateAddress,
            delegateName: delegateName
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            votedReferendaView.controller,
            animated: true
        )
    }

    func showAddDelegation(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) {
        guard
            let tracksView = GovernanceAddDelegationTracksViewFactory.createView(
                for: state,
                delegate: delegate
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            tracksView.controller,
            animated: true
        )
    }

    func showTracks(
        from view: GovernanceDelegateInfoViewProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal]
    ) {
        guard let tracksView = CommonDelegationTracksViewFactory.createView(
            for: state,
            tracks: tracks,
            delegations: delegations
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        tracksView.controller.modalTransitioningFactory = factory
        tracksView.controller.modalPresentationStyle = .custom

        view?.controller.present(tracksView.controller, animated: true)
    }

    func showEditDelegation(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) {
        guard let tracksView = GovEditDelegationTracksViewFactory.createView(for: state, delegate: delegate) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            tracksView.controller,
            animated: true
        )
    }

    func showRevokeDelegation(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) {
        guard
            let tracksView = GovRevokeDelegationTracksViewFactory.createView(
                for: state,
                delegate: delegate
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            tracksView.controller,
            animated: true
        )
    }
}
