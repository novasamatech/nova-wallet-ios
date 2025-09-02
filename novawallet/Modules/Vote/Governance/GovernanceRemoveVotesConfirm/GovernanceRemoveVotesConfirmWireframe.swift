import Foundation
import UIKit_iOS

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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        tracksView.controller.modalTransitioningFactory = factory
        tracksView.controller.modalPresentationStyle = .custom

        view?.controller.present(tracksView.controller, animated: true)
    }

    func skip(on view: GovernanceRemoveVotesConfirmViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
