import Foundation

final class GovernanceDelegateConfirmWireframe: GovernanceDelegateConfirmWireframeProtocol, ModalAlertPresenting {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func showTracks(from _: GovernanceDelegateConfirmViewProtocol?, tracks _: [GovernanceTrackInfoLocal]) {
        // TODO: #860pmdth7
    }

    func complete(on view: GovernanceDelegateConfirmViewProtocol?, locale: Locale) {
        guard let yourDelegations = GovernanceYourDelegationsViewFactory.createView(for: state) else {
            return
        }

        yourDelegations.controller.hidesBottomBarWhenPushed = true

        let presenter = view?.controller.navigationController
        presenter?.popToRootViewController(animated: false)

        presenter?.pushViewController(yourDelegations.controller, animated: true)

        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        presentSuccessNotification(title, from: presenter, completion: nil)
    }
}
