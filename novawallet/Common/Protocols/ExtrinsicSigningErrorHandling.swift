import Foundation

protocol ExtrinsicSigningErrorHandling {
    func handleExtrinsicSigningErrorPresentation(
        _ error: Error,
        view: ControllerBackedProtocol?,
        closeAction: ExtrinsicSubmissionPresentingAction?,
        completionClosure: ((Bool) -> Void)?
    ) -> Bool
}

extension ExtrinsicSigningErrorHandling where Self: MessageSheetPresentable & ErrorPresentable {
    @discardableResult
    func handleExtrinsicSigningErrorPresentationElseDefault(
        _ error: Error,
        view: ControllerBackedProtocol?,
        closeAction: ExtrinsicSubmissionPresentingAction?,
        locale: Locale?,
        completionClosure: ((Bool) -> Void)?
    ) -> Bool {
        guard
            !handleExtrinsicSigningErrorPresentation(
                error,
                view: view,
                closeAction: closeAction,
                completionClosure: completionClosure
            ) else {
            return true
        }

        return present(error: error, from: view, locale: locale)
    }
}

extension ExtrinsicSigningErrorHandling where Self: MessageSheetPresentable {
    private func closeFlowIfNeeded(
        on view: ControllerBackedProtocol,
        closeAction: ExtrinsicSubmissionPresentingAction?,
        completionClosure: ((Bool) -> Void)?
    ) {
        guard let closeAction = closeAction else {
            completionClosure?(false)
            return
        }

        switch closeAction {
        case .dismiss:
            let presenter = view.controller.navigationController?.presentingViewController

            presenter?.dismiss(animated: true) {
                completionClosure?(true)
            }
        case .dismissAllModals:
            let root = view.controller.view.window?.rootViewController

            root?.dismiss(animated: true) {
                completionClosure?(true)
            }
        case .pop:
            let presenter = view.controller.navigationController
            presenter?.popToRootViewController(animated: true)

            completionClosure?(true)
        case .popBack:
            let presenter = view.controller.navigationController
            presenter?.popViewController(animated: true)

            completionClosure?(true)
        case .popBaseAndDismiss:
            MainTransitionHelper.dismissAndPopBack(from: view) { _ in
                completionClosure?(true)
            }
        case let .dismissWithPostNavigation(postNavigationClosure):
            let presenter = view.controller.navigationController?.presentingViewController

            presenter?.dismiss(animated: true) {
                postNavigationClosure()
                completionClosure?(true)
            }
        }
    }

    func handleExtrinsicSigningErrorPresentation(
        _ error: Error,
        view: ControllerBackedProtocol?,
        closeAction: ExtrinsicSubmissionPresentingAction?,
        completionClosure: ((Bool) -> Void)?
    ) -> Bool {
        guard let view = view else {
            completionClosure?(false)
            return false
        }

        if error.isWatchOnlySigning {
            presentNoSigningView(from: view) {
                self.closeFlowIfNeeded(
                    on: view,
                    closeAction: closeAction,
                    completionClosure: completionClosure
                )
            }

            return true
        } else if error.isSigningCancelled {
            completionClosure?(false)
            return true
        } else if error.isSigningClosed {
            closeFlowIfNeeded(
                on: view,
                closeAction: closeAction,
                completionClosure: completionClosure
            )
            return true
        } else if let notSupportedSigner = error.notSupportedSignerType {
            presentSignerNotSupportedView(from: view, type: notSupportedSigner) {
                self.closeFlowIfNeeded(
                    on: view,
                    closeAction: closeAction,
                    completionClosure: completionClosure
                )
            }

            return true
        } else {
            return false
        }
    }
}
