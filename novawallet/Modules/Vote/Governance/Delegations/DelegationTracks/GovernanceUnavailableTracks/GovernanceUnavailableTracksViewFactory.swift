import Foundation
import Foundation_iOS
import UIKit_iOS

struct GovernanceUnavailableTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate: GovernanceUnavailableTracksDelegate,
        votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    ) -> GovernanceUnavailableTracksViewProtocol? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovernanceUnavailableTracksWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = GovernanceUnavailableTracksPresenter(
            wireframe: wireframe,
            delegate: delegate,
            votedTracks: votedTracks,
            delegatedTracks: delegatedTracks,
            chain: chain,
            trackViewModelFactory: GovernanceTrackViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = GovUnavailableTracksViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let estimatedContentHeight = GovUnavailableTracksViewController.estimatePreferredHeight(
            for: votedTracks,
            delegatedTracks: delegatedTracks
        )

        view.preferredContentSize = .init(
            width: 0,
            height: min(estimatedContentHeight, maxHeight)
        )

        presenter.view = view

        return view
    }
}
