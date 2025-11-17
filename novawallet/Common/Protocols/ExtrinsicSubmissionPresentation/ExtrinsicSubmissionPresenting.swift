import UIKit

enum ExtrinsicSubmissionPresentingAction {
    case dismiss
    case dismissAllModals
    case pop
    case popBack
    case popBaseAndDismiss
    case dismissWithPostNavigation(() -> Void)
    case popToViewController(UIViewController)
    case popRootAndPush(UIViewController)
    case postNavigation(() -> Void)
}

protocol ExtrinsicSubmissionCompliting {
    func handleCompletion(
        from view: ControllerBackedProtocol?,
        alertPresenting: ModalAlertPresenting,
        params: ExtrinsicSubmissionPresentingParams
    ) -> Bool
}

struct ExtrinsicSubmissionPresentingParams {
    enum Title {
        case preferred(String)
        case general(Locale?)
    }

    let title: Title
    let sender: ExtrinsicSenderResolution?
    let preferredCompletionAction: ExtrinsicSubmissionPresentingAction
}

protocol ExtrinsicSubmissionPresenting: AnyObject {
    func presentExtrinsicSubmission(
        from view: ControllerBackedProtocol?,
        params: ExtrinsicSubmissionPresentingParams
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
        let params = ExtrinsicSubmissionPresentingParams(
            title: .general(locale),
            sender: sender,
            preferredCompletionAction: completionAction
        )

        presentExtrinsicSubmission(from: view, params: params)
    }

    func presentExtrinsicSubmission(
        from view: ControllerBackedProtocol?,
        params: ExtrinsicSubmissionPresentingParams
    ) {
        for completer in completionHandlers {
            if completer.handleCompletion(
                from: view,
                alertPresenting: self,
                params: params
            ) {
                return
            }
        }
    }
}
