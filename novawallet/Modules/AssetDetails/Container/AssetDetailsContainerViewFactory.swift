import Foundation_iOS

final class AssetDetailsContainerViewFactory: AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        operationState: AssetOperationState,
        ahmInfoSnapshot: AHMInfoService.Snapshot
    ) -> AssetDetailsContainerViewProtocol? {
        let swapState = SwapTokensFlowState(
            assetListObservable: operationState.assetListObservable,
            assetExchangeParams: AssetExchangeGraphProvidingParams(
                wallet: SelectedWalletSettings.shared.value
            )
        )

        guard
            let accountView = AssetDetailsViewFactory.createView(
                chainAsset: chainAsset,
                operationState: operationState,
                swapState: swapState,
                ahmInfoSnapshot: ahmInfoSnapshot
            ),
            let historyView = TransactionHistoryViewFactory.createView(
                chainAsset: chainAsset,
                operationState: operationState,
                swapState: swapState
            ) else {
            return nil
        }
        let view = AssetDetailsContainerViewController()

        view.content = accountView
        view.draggable = historyView
        view.hidesBottomBarWhenPushed = true
        return view
    }
}
