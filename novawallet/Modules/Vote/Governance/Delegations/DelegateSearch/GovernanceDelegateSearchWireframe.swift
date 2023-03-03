import Foundation

final class GovernanceDelegateSearchWireframe: GovernanceDelegateSearchWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showInfo(from view: GovernanceDelegateSearchViewProtocol?, delegate: GovernanceDelegateLocal) {
        guard let infoView = GovernanceDelegateInfoViewFactory.createView(for: state, delegate: delegate) else {
            return
        }

        view?.controller.navigationController?.pushViewController(infoView.controller, animated: true)
    }
}
