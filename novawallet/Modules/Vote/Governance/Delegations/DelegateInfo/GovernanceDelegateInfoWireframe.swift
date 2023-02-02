import Foundation

final class GovernanceDelegateInfoWireframe: GovernanceDelegateInfoWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showFullDescription(
        from _: GovernanceDelegateInfoViewProtocol?,
        longDescription _: String
    ) {
        // TODO: Task #860pmdtfg
    }

    func showDelegations(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress
    ) {
        guard let delegationListView = DelegationListViewFactory.createView(
            accountAddress: delegateAddress,
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            delegationListView.controller,
            animated: true
        )
    }

    func showRecentVotes(
        from _: GovernanceDelegateInfoViewProtocol?,
        delegateAddress _: AccountAddress
    ) {
        // TODO: Task #860pmdtg6
    }

    func showAllVotes(
        from _: GovernanceDelegateInfoViewProtocol?,
        delegateAddress _: AccountAddress
    ) {
        // TODO: Task #860pmdtg6
    }

    func showAddDelegation(from _: GovernanceDelegateInfoViewProtocol?) {
        // TODO: Task #860pmdtgh
    }
}
