import Foundation

final class SwipeGovVotingListWireframe: SwipeGovVotingListWireframeProtocol {
    let sharedState: GovernanceSharedState

    init(sharedState: GovernanceSharedState) {
        self.sharedState = sharedState
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        initData: ReferendumDetailsInitData
    ) {
        guard let detailsView = SwipeGovReferendumDetailsViewFactory.createView(
            for: sharedState,
            initData: initData
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: detailsView.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData
    ) {
        guard let confirmationView = SwipeGovVotingConfirmViewFactory.createView(
            for: sharedState,
            initData: initData
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }
}
