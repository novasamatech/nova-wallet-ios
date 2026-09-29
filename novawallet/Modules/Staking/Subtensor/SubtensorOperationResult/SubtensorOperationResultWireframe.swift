import UIKit

final class SubtensorOperationResultWireframe: SubtensorResultWireframeProtocol, MessageSheetPresentable,
    ExtrinsicSigningErrorHandling {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func closeForRetry(from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        closeResult(from: view, completion: completion)
    }

    func closeOperation(from _: ControllerBackedProtocol?) {
        SubtensorModalStack.dismiss(animated: true)
    }

    func showSubnetDiscovery(from view: ControllerBackedProtocol?) {
        let flowNavigation = SubtensorModalStack.flowNavigation()

        closeResult(from: view) {
            flowNavigation?.popToRootViewController(animated: false)
            (flowNavigation?.viewControllers.first as? SubtensorEarnFlowRoot)?.startSubnetDiscovery()
        }
    }

    func presentSigningFailure(_ error: Error, from view: ControllerBackedProtocol?) {
        let closeAction = ExtrinsicSubmissionPresentingAction.postNavigation { [self] in
            closeOperation(from: view)
        }

        _ = handleExtrinsicSigningErrorPresentation(
            error,
            view: view,
            closeAction: closeAction,
            completionClosure: nil
        )
    }
}

private extension SubtensorOperationResultWireframe {
    func closeResult(from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        guard let presenting = view?.controller.presentingViewController else {
            completion()
            return
        }

        presenting.dismiss(animated: true, completion: completion)
    }
}
