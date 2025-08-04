import Foundation
import UIKit_iOS

final class GovernanceDelegateConfirmWireframe: GovernanceDelegateConfirmWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showTracks(from view: GovernanceDelegateConfirmViewProtocol?, tracks: [GovernanceTrackInfoLocal]) {
        guard let tracksView = CommonDelegationTracksViewFactory.createView(
            for: state,
            tracks: tracks
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        tracksView.controller.modalTransitioningFactory = factory
        tracksView.controller.modalPresentationStyle = .custom

        view?.controller.present(tracksView.controller, animated: true)
    }

    func complete(
        on view: GovernanceDelegateConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution?,
        locale: Locale
    ) {
        let presenter = view?.controller.navigationController

        if
            let yourDelegations = presenter?.viewControllers.first(
                where: { $0 is GovernanceYourDelegationsViewProtocol }
            ) {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .popToViewController(yourDelegations),
                locale: locale
            )
        } else {
            guard let yourDelegations = GovernanceYourDelegationsViewFactory.createView(for: state) else {
                return
            }

            yourDelegations.controller.hidesBottomBarWhenPushed = true

            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .popRootAndPush(yourDelegations.controller),
                locale: locale
            )
        }
    }

    func skip(on view: GovernanceDelegateConfirmViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
