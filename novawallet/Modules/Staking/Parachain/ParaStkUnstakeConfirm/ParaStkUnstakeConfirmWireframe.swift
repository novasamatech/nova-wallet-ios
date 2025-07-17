import Foundation

final class ParaStkUnstakeConfirmWireframe: ParaStkUnstakeConfirmWireframeProtocol,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func complete(on view: CollatorStkUnstakeConfirmViewProtocol?, locale: Locale) {
        // TODO: MS navigation
        presentExtrinsicSubmission(
            from: view,
            sender: nil,
            completionAction: .dismiss,
            locale: locale
        )
    }
}
