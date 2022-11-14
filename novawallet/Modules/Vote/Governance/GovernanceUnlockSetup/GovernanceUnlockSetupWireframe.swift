import Foundation

final class GovernanceUnlockSetupWireframe: GovernanceUnlockSetupWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showConfirm(
        from view: GovernanceUnlockSetupViewProtocol?,
        initData: GovernanceUnlockConfirmInitData
    ) {
        guard let confirmView = GovernanceUnlockConfirmViewFactory.createView(
            for: state,
            initData: initData
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
