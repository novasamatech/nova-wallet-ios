import Foundation

final class SwapConfirmWireframe: SwapConfirmWireframeProtocol {
    let flowState: SwapTokensFlowStateProtocol
    let flowHandler: SwapExecutionFlowHandling

    init(
        flowState: SwapTokensFlowStateProtocol,
        flowHandler: SwapExecutionFlowHandling
    ) {
        self.flowState = flowState
        self.flowHandler = flowHandler
    }

    func showSwapExecution(
        from view: SwapConfirmViewProtocol?,
        model: SwapExecutionModel
    ) {
        guard
            let swapExecutionView = SwapExecutionViewFactory.createView(
                for: model,
                flowState: flowState,
                flowHandler: flowHandler
            ) else {
            return
        }

        let flowHost = view?.controller.navigationController?.presentingViewController

        flowHost?.dismiss(animated: true) {
            flowHost?.presentWithCardLayout(swapExecutionView.controller, animated: true)
        }
    }

    func completeDelayedSubmission(
        from view: SwapConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        locale: Locale
    ) {
        presentExtrinsicSubmission(
            from: view,
            sender: sender,
            completionAction: .dismiss,
            locale: locale
        )

        flowHandler.completeDelayedSubmission(
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

        view?.controller.present(navigationController, animated: true)
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

        view?.controller.present(navigationController, animated: true)
    }
}
