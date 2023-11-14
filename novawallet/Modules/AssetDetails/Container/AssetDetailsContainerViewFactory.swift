import SoraFoundation

final class AssetDetailsContainerViewFactory: AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        operationState: AssetOperationState
    ) -> AssetDetailsContainerViewProtocol? {
        guard
            let accountView = AssetDetailsViewFactory.createView(
                chain: chain,
                asset: asset,
                operationState: operationState
            ),
            let historyView = TransactionHistoryViewFactory.createView(
                chainAsset: .init(chain: chain, asset: asset),
                operationState: operationState
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
