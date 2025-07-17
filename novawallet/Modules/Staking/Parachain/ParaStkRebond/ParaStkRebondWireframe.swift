import Foundation

final class ParaStkRebondWireframe: ParaStkRebondWireframeProtocol,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func complete(on view: ParaStkRebondViewProtocol?, locale: Locale) {
        // TODO: MS navigation
        presentExtrinsicSubmission(
            from: view,
            sender: nil,
            completionAction: .dismiss,
            locale: locale
        )
    }
}
