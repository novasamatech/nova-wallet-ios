import Foundation

final class GovRevokeDelegationTracksWireframe: GovernanceSelectTracksWireframe {
    let state: GovernanceSharedState
    let delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>

    init(state: GovernanceSharedState, delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>) {
        self.state = state
        self.delegateDisplayInfo = delegateDisplayInfo
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    ) {
        guard
            let confirmView = GovRevokeDelegationConfirmViewFactory.createView(
                for: state,
                selectedTracks: tracks,
                delegate: delegateDisplayInfo
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
