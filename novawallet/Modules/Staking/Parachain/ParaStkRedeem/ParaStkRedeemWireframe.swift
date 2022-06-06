import Foundation

final class ParaStkRedeemWireframe: ParaStkRedeemWireframeProtocol,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func complete(on view: ParaStkRedeemViewProtocol?, locale: Locale) {
        presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: locale)
    }
}
