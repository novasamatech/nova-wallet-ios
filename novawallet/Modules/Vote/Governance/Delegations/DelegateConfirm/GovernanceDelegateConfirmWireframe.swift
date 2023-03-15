import Foundation
import SoraUI

final class GovernanceDelegateConfirmWireframe: GovernanceDelegateConfirmWireframeProtocol, ModalAlertPresenting {
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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        tracksView.controller.modalTransitioningFactory = factory
        tracksView.controller.modalPresentationStyle = .custom

        view?.controller.present(tracksView.controller, animated: true)
    }

    func complete(on view: GovernanceDelegateConfirmViewProtocol?, locale: Locale) {
        let presenter = view?.controller.navigationController

        if
            let yourDelegations = presenter?.viewControllers.first(
                where: { $0 is GovernanceYourDelegationsViewProtocol }
            ) {
            presenter?.popToViewController(yourDelegations, animated: true)
        } else {
            guard let yourDelegations = GovernanceYourDelegationsViewFactory.createView(for: state) else {
                return
            }

            yourDelegations.controller.hidesBottomBarWhenPushed = true

            presenter?.popToRootViewController(animated: false)

            presenter?.pushViewController(yourDelegations.controller, animated: true)
        }

        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        presentSuccessNotification(title, from: presenter, completion: nil)
    }

    func skip(on view: GovernanceDelegateConfirmViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
