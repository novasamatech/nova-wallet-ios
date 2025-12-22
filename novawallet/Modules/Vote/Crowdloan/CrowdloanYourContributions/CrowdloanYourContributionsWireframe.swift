import Foundation

final class CrowdloanYourContributionsWireframe: CrowdloanContributionsWireframeProtocol {
    let state: CrowdloanSharedState

    init(state: CrowdloanSharedState) {
        self.state = state
    }

    func showUnlock(from view: CrowdloanContributionsViewProtocol?, model: CrowdloanUnlock) {
        guard let unlockView = CrowdloanUnlockViewFactory.createView(
            for: state,
            unlockModel: model
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: unlockView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}
