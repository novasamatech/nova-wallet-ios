import Foundation

final class MythosStakingRedeemWireframe: MythosStakingRedeemWireframeProtocol, ModalAlertPresenting {
    func complete(
        view: CollatorStakingRedeemViewProtocol?,
        redeemedAll: Bool,
        locale: Locale
    ) {
        let action: ExtrinsicSubmissionPresentingAction = redeemedAll ? .popBaseAndDismiss : .dismiss

        presentExtrinsicSubmission(
            from: view,
            completionAction: action,
            locale: locale
        )
    }
}
