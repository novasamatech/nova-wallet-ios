import Foundation

final class TinderGovWireframe: TinderGovWireframeProtocol {
    let sharedState: GovernanceSharedState

    init(sharedState: GovernanceSharedState) {
        self.sharedState = sharedState
    }

    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showVoteSetup(from _: ControllerBackedProtocol?) {
//        guard let voteSetupView = ReferendumVoteSetupViewFactory.createView(
//            for: sharedState,
//            referendum: ,
//            initData:
//        )
    }
}
