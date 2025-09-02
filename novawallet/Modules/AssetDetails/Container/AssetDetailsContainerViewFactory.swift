import Foundation_iOS

final class AssetDetailsContainerViewFactory: AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        operationState: AssetOperationState
    ) -> AssetDetailsContainerViewProtocol? {
        let swapState = SwapTokensFlowState(
            assetListObservable: operationState.assetListObservable,
            assetExchangeParams: AssetExchangeGraphProvidingParams(
                wallet: SelectedWalletSettings.shared.value
            )
        )

        guard
            let accountView = AssetDetailsViewFactory.createView(
                chain: chain,
                asset: asset,
                operationState: operationState,
                swapState: swapState
            ),
            let historyView = TransactionHistoryViewFactory.createView(
                chainAsset: .init(chain: chain, asset: asset),
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
