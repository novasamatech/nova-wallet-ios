import Foundation

final class GovernanceDelegateSetupWireframe: GovernanceDelegateSetupWireframeProtocol {
    let state: GovernanceSharedState
    let delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>

    init(
        state: GovernanceSharedState,
        delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    ) {
        self.state = state
        self.delegateDisplayInfo = delegateDisplayInfo
    }

    func showConfirm(from view: GovernanceDelegateSetupViewProtocol?, delegation: GovernanceNewDelegation) {
        guard
            let confirmView = GovernanceDelegateConfirmViewFactory.createAddDelegationView(
                for: state,
                delegation: delegation,
                delegationDisplayInfo: delegateDisplayInfo
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
