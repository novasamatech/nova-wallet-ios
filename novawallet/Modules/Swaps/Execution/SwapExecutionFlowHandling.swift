import UIKit

protocol SwapExecutionFlowHandling {
    func completeFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    )

    func retryFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    )

    func closeFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        isSwapCompleted: Bool
    )

    func completeDelayedSubmission(payChainAsset: ChainAsset, receiveChainAsset: ChainAsset)
}

extension SwapExecutionFlowHandling {
    func flowHost(of executionView: ControllerBackedProtocol?) -> UIViewController? {
        executionView?.controller.presentingViewController
    }
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

extension SwapExecutionPresentedFlowHandler: SwapExecutionFlowHandling {
    func completeFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset _: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        flowHost(of: view)?.dismiss(animated: true) {
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

        let host = flowHost(of: view)

        let navigationController = NovaNavigationController(rootViewController: swapView.controller)

        host?.dismiss(animated: true) {
            host?.presentWithCardLayout(navigationController, animated: true)
        }
    }

    func closeFlow(
        from view: ControllerBackedProtocol?,
        payChainAsset _: ChainAsset,
        receiveChainAsset _: ChainAsset,
        isSwapCompleted _: Bool
    ) {
        flowHost(of: view)?.dismiss(animated: true)
    }

    func completeDelayedSubmission(payChainAsset _: ChainAsset, receiveChainAsset _: ChainAsset) {}
}
