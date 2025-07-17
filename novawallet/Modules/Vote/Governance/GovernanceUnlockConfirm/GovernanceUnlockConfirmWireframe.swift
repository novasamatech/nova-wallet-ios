import Foundation

final class GovernanceUnlockConfirmWireframe: GovernanceUnlockConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(on view: GovernanceUnlockConfirmViewProtocol?, locale: Locale) {
        // TODO: MS navigation
        presentExtrinsicSubmission(
            from: view,
            sender: nil,
            completionAction: .dismiss,
            locale: locale
        )
    }

    func skip(on view: GovernanceUnlockConfirmViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
