import Foundation

final class GovRevokeDelegationTracksWireframe: GovernanceSelectTracksWireframe {
    let state: GovernanceSharedState
    let delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>

    init(state: GovernanceSharedState, delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>) {
        self.state = state
        self.delegateDisplayInfo = delegateDisplayInfo
    }

    override func proceed(from _: ControllerBackedProtocol?, tracks _: [GovernanceTrackInfoLocal]) {}
}
