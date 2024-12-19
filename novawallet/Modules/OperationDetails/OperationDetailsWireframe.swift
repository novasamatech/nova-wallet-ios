import Foundation

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    let operationState: AssetOperationState
    let swapState: SwapTokensFlowStateProtocol

    init(
        operationState: AssetOperationState,
        swapState: SwapTokensFlowStateProtocol
    ) {
        self.operationState = operationState
        self.swapState = swapState
    }

    func showSend(
        from view: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    ) {
        guard let transferView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: displayAddress
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(transferView.controller, animated: true)
    }

    func showSwapSetup(
        from view: OperationDetailsViewProtocol?,
        state: SwapSetupInitState
    ) {
        guard let swapView = SwapSetupViewFactory.createView(
            state: swapState,
            initState: state,
            swapCompletionClosure: operationState.swapCompletionClosure
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(swapView.controller, animated: true)
    }
}
