import Foundation
import SoraUI
import SoraFoundation

struct CommonDelegationTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        tracks: [TrackVote]
    ) -> CommonDelegationTracksViewProtocol? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        let viewModelFactory = GovernanceTrackViewModelFactory()
        let stringFactory = ReferendumDisplayStringFactory()

        let presenter = CommonDelegationTracksPresenter(
            tracks: tracks,
            chain: chain,
            viewModelFactory: viewModelFactory,
            stringFactory: stringFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = CommonDelegationTracksViewController(presenter: presenter)

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let estimatedContentHeight = CommonDelegationTracksViewController.estimatePreferredHeight(
            for: tracks
        )

        view.preferredContentSize = .init(
            width: 0,
            height: min(estimatedContentHeight, maxHeight)
        )

        presenter.view = view

        return view
    }
}
