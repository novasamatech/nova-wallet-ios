import Foundation

protocol SubtensorOperationResultDelegate: AnyObject {
    func didRequestRetry()
}

protocol SubtensorOperationResultPresenting {
    var state: SubtensorStakingSharedStateProtocol { get }

    func showOperationResult(
        from view: ControllerBackedProtocol?,
        request: SubtensorOperationResultRequest,
        delegate: SubtensorOperationResultDelegate
    )
}

extension SubtensorOperationResultPresenting {
    func showOperationResult(
        from view: ControllerBackedProtocol?,
        request: SubtensorOperationResultRequest,
        delegate: SubtensorOperationResultDelegate
    ) {
        guard let resultView = SubtensorOperationResultViewFactory.createView(
            for: state,
            request: request,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.present(resultView.controller, animated: true)
    }
}
