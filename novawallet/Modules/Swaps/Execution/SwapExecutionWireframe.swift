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
        receiveChainAsset: ChainAsset
    ) {
        let presenter = view?.controller.presentingViewController

        presenter?.dismiss(animated: true) {
            self.completionClosure?(receiveChainAsset)
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
