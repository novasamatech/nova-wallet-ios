import Foundation

final class DelegateVotedReferendaWireframe: DelegateVotedReferendaWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showReferendumDetails(from view: ControllerBackedProtocol?, initData: ReferendumDetailsInitData) {
        guard
            let detailsView = ReferendumDetailsViewFactory.createView(
                for: state,
                initData: initData
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }
}
