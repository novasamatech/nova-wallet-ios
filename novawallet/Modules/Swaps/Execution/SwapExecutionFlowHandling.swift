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

    func completeDelayedSubmission(
        from reviewView: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        presentingSubmission: (ControllerBackedProtocol?) -> Void
    )
}

extension SwapExecutionFlowHandling {
    func flowHost(of executionView: ControllerBackedProtocol?) -> UIViewController? {
        executionView?.controller.presentingViewController
    }
}

final class SwapExecutionPresentedFlowHandler {
    let flowState: SwapTokensFlowStateProtocol
    let completionClosure: SwapCompletionClosure?

    weak var formView: ControllerBackedProtocol?

    init(
        flowState: SwapTokensFlowStateProtocol,
        completionClosure: SwapCompletionClosure?
    ) {
        self.flowState = flowState
        self.completionClosure = completionClosure
    }
}

private extension SwapExecutionPresentedFlowHandler {
    var flowPresenter: UIViewController? {
        formView?.controller.presentingViewController
    }
}

extension SwapExecutionPresentedFlowHandler: SwapExecutionFlowHandling {
    func completeFlow(
        from _: ControllerBackedProtocol?,
        payChainAsset _: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        flowPresenter?.dismiss(animated: true) {
            self.completionClosure?(receiveChainAsset)
        }
    }

    func retryFlow(
        from _: ControllerBackedProtocol?,
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

        let host = flowPresenter

        let navigationController = NovaNavigationController(rootViewController: swapView.controller)

        host?.dismiss(animated: true) {
            host?.presentWithCardLayout(navigationController, animated: true)
        }
    }

    func closeFlow(
        from _: ControllerBackedProtocol?,
        payChainAsset _: ChainAsset,
        receiveChainAsset _: ChainAsset,
        isSwapCompleted _: Bool
    ) {
        flowPresenter?.dismiss(animated: true)
    }

    func completeDelayedSubmission(
        from _: ControllerBackedProtocol?,
        payChainAsset _: ChainAsset,
        receiveChainAsset _: ChainAsset,
        presentingSubmission: (ControllerBackedProtocol?) -> Void
    ) {
        presentingSubmission(formView)
    }
}
