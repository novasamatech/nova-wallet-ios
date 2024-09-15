import Foundation

final class SwipeGovVotingListWireframe: SwipeGovVotingListWireframeProtocol {
    let sharedState: GovernanceSharedState

    init(sharedState: GovernanceSharedState) {
        self.sharedState = sharedState
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showSetup(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData,
        changing invalidItems: [VotingBasketItemLocal]
    ) {
        guard let setupView = SwipeGovSetupViewFactory.createView(
            for: sharedState,
            initData: initData,
            changing: invalidItems
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: setupView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
