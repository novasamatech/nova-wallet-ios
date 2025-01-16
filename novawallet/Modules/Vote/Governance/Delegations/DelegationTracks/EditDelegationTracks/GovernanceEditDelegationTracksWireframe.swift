import Foundation
import UIKit_iOS

final class GovEditDelegationTracksWireframe: GovernanceSelectTracksWireframe,
    GovEditDelegationTracksWireframeProtocol {
    let state: GovernanceSharedState
    let delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>

    init(state: GovernanceSharedState, delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>) {
        self.state = state
        self.delegateDisplayInfo = delegateDisplayInfo
    }

    func showRemoveVotes(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    ) {
        guard
            let removeVotesView = GovernanceRemoveVotesConfirmViewFactory.createView(
                for: state,
                tracks: tracks
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            removeVotesView.controller,
            animated: true
        )
    }

    func presentUnavailableTracks(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceUnavailableTracksDelegate,
        votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    ) {
        guard
            let presentingView = GovernanceUnavailableTracksViewFactory.createView(
                for: state,
                delegate: delegate,
                votedTracks: votedTracks,
                delegatedTracks: delegatedTracks
            ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        presentingView.controller.modalTransitioningFactory = factory
        presentingView.controller.modalPresentationStyle = .custom

        view?.controller.present(presentingView.controller, animated: true)
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    ) {
        let newDelegateInfo = GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>(
            additions: tracks,
            delegateMetadata: delegateDisplayInfo.delegateMetadata,
            delegateIdentity: delegateDisplayInfo.delegateIdentity
        )

        guard
            let setupView = GovernanceDelegateSetupViewFactory.createEditDelegationView(
                for: state,
                delegateId: delegateDisplayInfo.additions,
                delegateDisplayInfo: newDelegateInfo
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }
}
