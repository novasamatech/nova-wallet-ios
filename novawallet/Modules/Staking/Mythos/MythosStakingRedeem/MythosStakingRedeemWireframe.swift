import Foundation

final class MythosStakingRedeemWireframe: MythosStakingRedeemWireframeProtocol, ModalAlertPresenting {
    func complete(
        view: CollatorStakingRedeemViewProtocol?,
        redeemedAll: Bool,
        locale: Locale
    ) {
        let action: ExtrinsicSubmissionPresentingAction = redeemedAll ? .popBaseAndDismiss : .dismiss

        // TODO: MS navigation
        presentExtrinsicSubmission(
            from: view,
            sender: nil,
            completionAction: action,
            locale: locale
        )
    }
}
