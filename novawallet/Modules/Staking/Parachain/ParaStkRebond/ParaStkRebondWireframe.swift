import Foundation

final class ParaStkRebondWireframe: ParaStkRebondWireframeProtocol,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func complete(on view: ParaStkRebondViewProtocol?, locale: Locale) {
        presentExtrinsicSubmission(from: view, completionAction: .dismiss, locale: locale)
    }
}
