import Foundation

final class GovernanceYourDelegationsWireframe: GovernanceYourDelegationsWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showAddDelegation(
        from view: GovernanceYourDelegationsViewProtocol?,
        yourDelegations: [GovernanceYourDelegationGroup]
    ) {
        guard let addDelegation = AddDelegationViewFactory.createView(
            state: state,
            yourDelegations: yourDelegations
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(addDelegation.controller, animated: true)
    }

    func showDelegateInfo(from view: GovernanceYourDelegationsViewProtocol?, delegate: GovernanceDelegateLocal) {
        guard let delegateInfo = GovernanceDelegateInfoViewFactory.createView(for: state, delegate: delegate) else {
            return
        }

        view?.controller.navigationController?.pushViewController(delegateInfo.controller, animated: true)
    }
}
