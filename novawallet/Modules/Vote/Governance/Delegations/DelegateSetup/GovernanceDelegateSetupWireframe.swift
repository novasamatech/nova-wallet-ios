import Foundation

final class GovernanceDelegateSetupWireframe: GovernanceDelegateSetupWireframeProtocol {
    let state: GovernanceSharedState
    let delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    let flowType: GovernanceDelegationFlowType

    init(
        state: GovernanceSharedState,
        delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>,
        flowType: GovernanceDelegationFlowType
    ) {
        self.state = state
        self.delegateDisplayInfo = delegateDisplayInfo
        self.flowType = flowType
    }

    func showConfirm(from view: GovernanceDelegateSetupViewProtocol?, delegation: GovernanceNewDelegation) {
        let optConfirmView: ControllerBackedProtocol?

        switch flowType {
        case .add:
            optConfirmView = GovernanceDelegateConfirmViewFactory.createAddDelegationView(
                for: state,
                delegation: delegation,
                delegationDisplayInfo: delegateDisplayInfo
            )
        case .edit:
            optConfirmView = GovernanceDelegateConfirmViewFactory.createEditDelegationView(
                for: state,
                delegation: delegation,
                delegationDisplayInfo: delegateDisplayInfo
            )
        }

        guard let confirmView = optConfirmView else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
