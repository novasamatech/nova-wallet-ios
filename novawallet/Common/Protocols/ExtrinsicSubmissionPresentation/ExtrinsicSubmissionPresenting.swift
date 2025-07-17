import UIKit

enum ExtrinsicSubmissionPresentingAction {
    case dismiss
    case dismissAllModals
    case pop
    case popBack
    case popBaseAndDismiss
    case dismissWithPostNavigation(() -> Void)
}

protocol ExtrinsicSubmissionCompliting {
    func handleCompletion(
        from view: ControllerBackedProtocol?,
        alertPresenting: ModalAlertPresenting,
        sender: ExtrinsicSenderResolution?,
        completionAction: ExtrinsicSubmissionPresentingAction,
        locale: Locale?
    ) -> Bool
}

protocol ExtrinsicSubmissionPresenting: AnyObject {
    func presentExtrinsicSubmission(
        from view: ControllerBackedProtocol?,
        sender: ExtrinsicSenderResolution?,
        completionAction: ExtrinsicSubmissionPresentingAction,
        locale: Locale?
    )

    var completionHandlers: [ExtrinsicSubmissionCompliting] { get }
}

extension ExtrinsicSubmissionPresenting where Self: ModalAlertPresenting {
    var completionHandlers: [ExtrinsicSubmissionCompliting] {
        [
            ExtrinsicSubmissionDelayedCompleter(),
            ExtrinsicSubmissionRegularCompleter()
        ]
    }

    func presentExtrinsicSubmission(
        from view: ControllerBackedProtocol?,
        sender: ExtrinsicSenderResolution?,
        completionAction: ExtrinsicSubmissionPresentingAction,
        locale: Locale?
    ) {
        for completer in completionHandlers {
            if completer.handleCompletion(
                from: view,
                alertPresenting: self,
                sender: sender,
                completionAction: completionAction,
                locale: locale
            ) {
                return
            }
        }
    }
}
