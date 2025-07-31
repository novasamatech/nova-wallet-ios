import Foundation
import UIKit_iOS

final class GovRevokeDelegationConfirmWireframe: GovernanceRevokeDelegationConfirmWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showTracks(
        from view: GovernanceRevokeDelegationConfirmViewProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal]
    ) {
        guard
            let tracksView = CommonDelegationTracksViewFactory.createView(
                for: state,
                tracks: tracks,
                delegations: delegations
            ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        tracksView.controller.modalTransitioningFactory = factory
        tracksView.controller.modalPresentationStyle = .custom

        view?.controller.present(tracksView.controller, animated: true)
    }

    func complete(
        on view: GovernanceRevokeDelegationConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution?,
        allRemoved: Bool,
        locale: Locale
    ) {
        let presenter = view?.controller.navigationController

        if allRemoved {
            presentExtrinsicSubmission(
                from: view,
                sender: sender,
                completionAction: .pop,
                locale: locale
            )
        } else if
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
                completionAction: .popToViewController(yourDelegations.controller),
                locale: locale
            )
        }
    }

    func skip(on view: GovernanceRevokeDelegationConfirmViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
