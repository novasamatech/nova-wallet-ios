import Foundation

final class TinderGovWireframe: TinderGovWireframeProtocol {
    let sharedState: GovernanceSharedState

    init(sharedState: GovernanceSharedState) {
        self.sharedState = sharedState
    }

    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showVoteSetup(
        from view: ControllerBackedProtocol?,
        referendum: ReferendumIdLocal,
        initData: ReferendumVotingInitData
    ) {
        guard let setupView = TinderGovSetupViewFactory.createView(
            for: sharedState,
            referendum: referendum,
            initData: initData
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: setupView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
