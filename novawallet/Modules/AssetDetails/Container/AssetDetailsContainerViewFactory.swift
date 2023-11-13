import SoraFoundation

final class AssetDetailsContainerViewFactory: AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        assetListObservable: AssetListModelObservable,
        chain: ChainModel,
        asset: AssetModel,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> AssetDetailsContainerViewProtocol? {
        guard
            let accountView = AssetDetailsViewFactory.createView(
                assetListObservable: assetListObservable,
                chain: chain,
                asset: asset,
                swapCompletionClosure: swapCompletionClosure
            ),
            let historyView = TransactionHistoryViewFactory.createView(
                chainAsset: .init(chain: chain, asset: asset),
                assetListObservable: assetListObservable,
                swapCompletionClosure: swapCompletionClosure
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
