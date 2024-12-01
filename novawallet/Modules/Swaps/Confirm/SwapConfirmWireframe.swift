import Foundation

final class SwapConfirmWireframe: SwapConfirmWireframeProtocol {
    let flowState: SwapTokensFlowStateProtocol
    let completionClosure: SwapCompletionClosure?

    init(
        flowState: SwapTokensFlowStateProtocol,
        completionClosure: SwapCompletionClosure?
    ) {
        self.flowState = flowState
        self.completionClosure = completionClosure
    }

    func showSwapExecution(
        from view: SwapConfirmViewProtocol?,
        model: SwapExecutionModel
    ) {
        guard
            let swapExecutionView = SwapExecutionViewFactory.createView(
                for: model,
                flowState: flowState,
                completionClosure: completionClosure
            ) else {
            return
        }

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            presenter?.present(swapExecutionView.controller, animated: true)
        }
    }
}
