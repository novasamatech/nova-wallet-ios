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

        let navigationController = NovaNavigationController(
            rootViewController: confirmationView.controller
        )

        view?.controller.present(navigationController, animated: true)
    }
}
