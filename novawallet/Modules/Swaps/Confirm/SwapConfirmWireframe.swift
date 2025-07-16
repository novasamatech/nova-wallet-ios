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

    func complete(on view: SwapConfirmViewProtocol?) {
        // TODO: Figure out actual navigation
        let presenter = view?.controller.presentingViewController

        presenter?.dismiss(animated: true)
    }
}
