import Foundation

final class SwapExecutionWireframe: SwapExecutionWireframeProtocol {
    let flowState: SwapTokensFlowStateProtocol
    let flowHandler: SwapExecutionFlowHandling

    init(
        flowState: SwapTokensFlowStateProtocol,
        flowHandler: SwapExecutionFlowHandling
    ) {
        self.flowState = flowState
        self.flowHandler = flowHandler
    }

    func complete(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        flowHandler.completeFlow(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset
        )
    }

    func close(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        isSwapCompleted: Bool
    ) {
        flowHandler.closeFlow(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            isSwapCompleted: isSwapCompleted
        )
    }

    func showSwapSetup(
        from view: SwapExecutionViewProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    ) {
        flowHandler.retryFlow(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset
        )
    }

    func showRouteDetails(
        from view: ControllerBackedProtocol?,
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee
    ) {
        guard
            let routeDetailsView = SwapRouteDetailsViewFactory.createView(
                for: quote,
                fee: fee,
                state: flowState
            ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: routeDetailsView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }

    func showFeeDetails(
        from view: ControllerBackedProtocol?,
        operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee
    ) {
        guard
            let routeDetailsView = SwapFeeDetailsViewFactory.createView(
                for: operations,
                fee: fee,
                state: flowState
            ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: routeDetailsView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }
}
