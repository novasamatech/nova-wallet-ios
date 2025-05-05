import Foundation
import UIKit_iOS
import Foundation_iOS

struct CommonDelegationTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        tracks: [GovernanceTrackInfoLocal],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal] = [:]
    ) -> CommonDelegationTracksViewProtocol? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        let viewModelFactory = GovernanceTrackViewModelFactory()
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        let presenter = CommonDelegationTracksPresenter(
            tracks: tracks,
            delegations: delegations,
            chain: chain,
            viewModelFactory: viewModelFactory,
            stringFactory: referendumDisplayStringFactory,
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
