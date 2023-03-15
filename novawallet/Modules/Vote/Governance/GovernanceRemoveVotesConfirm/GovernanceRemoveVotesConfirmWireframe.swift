import Foundation
import SoraUI

final class GovRemoveVotesConfirmWireframe: GovernanceRemoveVotesConfirmWireframeProtocol,
    ModalAlertPresenting {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showTracks(
        from view: GovernanceRemoveVotesConfirmViewProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    ) {
        guard let tracksView = CommonDelegationTracksViewFactory.createView(
            for: state,
            tracks: tracks
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        tracksView.controller.modalTransitioningFactory = factory
        tracksView.controller.modalPresentationStyle = .custom

        view?.controller.present(tracksView.controller, animated: true)
    }
}
