import Foundation

final class SwapExecutionWireframe: SwapExecutionWireframeProtocol {
    let flowState: SwapTokensFlowStateProtocol
    let completionClosure: SwapCompletionClosure?

    init(
        flowState: SwapTokensFlowStateProtocol,
        completionClosure: SwapCompletionClosure?
    ) {
        self.flowState = flowState
        self.completionClosure = completionClosure
    }

    func complete(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset
    ) {
        let presenter = view?.controller.presentingViewController

        presenter?.dismiss(animated: true) {
            self.completionClosure?(payChainAsset)
        }
    }

    func showSwapSetup(
        from view: SwapExecutionViewProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        guard let swapView = SwapSetupViewFactory.createView(
            state: flowState,
            initState: .init(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset),
            swapCompletionClosure: completionClosure
        ) else {
            return
        }

        let presenter = view?.controller.presentingViewController

        let navigationController = NovaNavigationController(rootViewController: swapView.controller)

        presenter?.dismiss(animated: true) {
            presenter?.present(navigationController, animated: true)
        }
    }
}