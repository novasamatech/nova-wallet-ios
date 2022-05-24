import Foundation

final class ParaStkStakeConfirmWireframe: ParaStkStakeConfirmWireframeProtocol,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func complete(on view: ParaStkStakeConfirmViewProtocol?, locale: Locale) {
        presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: locale)
    }
}
