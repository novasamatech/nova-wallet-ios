import UIKit

protocol SwapExecutionFlowHandling {
    func completeFlow(from view: ControllerBackedProtocol?, receiveChainAsset: ChainAsset)

    func retryFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    )

    func closeFlow(from view: ControllerBackedProtocol?)
}

final class SwapExecutionPresentedFlowHandler {
    let flowState: SwapTokensFlowStateProtocol
    let completionClosure: SwapCompletionClosure?

    init(
        flowState: SwapTokensFlowStateProtocol,
        completionClosure: SwapCompletionClosure?
    ) {
        self.flowState = flowState
        self.completionClosure = completionClosure
    }
}

private extension SwapExecutionPresentedFlowHandler {
    func flowPresenter(for view: ControllerBackedProtocol?) -> UIViewController? {
        let flowHost = view?.controller.presentingViewController

        return flowHost?.presentingViewController ?? flowHost
    }
}

extension SwapExecutionPresentedFlowHandler: SwapExecutionFlowHandling {
    func completeFlow(from view: ControllerBackedProtocol?, receiveChainAsset: ChainAsset) {
        let presenter = flowPresenter(for: view)

        presenter?.dismiss(animated: true) {
            self.completionClosure?(receiveChainAsset)
        }
    }

    func retryFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        guard let swapView = SwapSetupViewFactory.createView(
            state: flowState,
            initState: .init(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset),
            source: .retry,
            swapCompletionClosure: completionClosure
        ) else {
            return
        }

        let presenter = flowPresenter(for: view)

        let navigationController = NovaNavigationController(rootViewController: swapView.controller)

        presenter?.dismiss(animated: true) {
            presenter?.presentWithCardLayout(navigationController, animated: true)
        }
    }

    func closeFlow(from view: ControllerBackedProtocol?) {
        flowPresenter(for: view)?.dismiss(animated: true)
    }
}
