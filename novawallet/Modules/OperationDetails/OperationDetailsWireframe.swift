import Foundation

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    let operationState: AssetOperationState

    init(
        operationState: AssetOperationState
    ) {
        self.operationState = operationState
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
            assetListObservable: operationState.assetListObservable,
            initState: state,
            swapCompletionClosure: operationState.swapCompletionClosure
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(swapView.controller, animated: true)
    }
}
