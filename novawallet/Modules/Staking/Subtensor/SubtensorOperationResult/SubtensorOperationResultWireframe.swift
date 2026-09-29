import UIKit

final class SubtensorOperationResultWireframe: SubtensorResultWireframeProtocol, MessageSheetPresentable,
    ExtrinsicSigningErrorHandling {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func closeForRetry(from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        guard let presenting = view?.controller.presentingViewController else {
            completion()
            return
        }

        presenting.dismiss(animated: true, completion: completion)
    }

    func closeOperation(from view: ControllerBackedProtocol?) {
        let flowController = view?.controller.presentingViewController
        let flowNavigation = flowController as? UINavigationController ?? flowController?.navigationController

        if let flowPresenter = flowNavigation?.presentingViewController {
            flowPresenter.dismiss(animated: true)
        } else {
            flowController?.dismiss(animated: true)
        }
    }

    func showSubnetDiscovery(from view: ControllerBackedProtocol?) {
        let flowController = view?.controller.presentingViewController
        let flowNavigation = flowController as? UINavigationController ?? flowController?.navigationController

        flowController?.dismiss(animated: true) {
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
