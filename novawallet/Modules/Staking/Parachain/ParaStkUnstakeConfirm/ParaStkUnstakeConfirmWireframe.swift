import Foundation

final class ParaStkUnstakeConfirmWireframe: ParaStkUnstakeConfirmWireframeProtocol,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func complete(on view: ParaStkUnstakeConfirmViewProtocol?, locale: Locale) {
        presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: locale)
    }
}
