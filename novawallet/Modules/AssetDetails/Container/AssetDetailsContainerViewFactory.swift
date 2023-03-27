import SoraFoundation

final class AssetDetailsContainerViewFactory: AssetDetailsContainerViewFactoryProtocol {
    static func createView(chain: ChainModel, asset: AssetModel) -> AssetDetailsContainerViewProtocol? {
        guard
            let accountView = AssetDetailsViewFactory.createView(
                chain: chain,
                asset: asset
            ),
            let historyView = TransactionHistoryViewFactory.createView(chainAsset: .init(chain: chain, asset: asset)) else {
            return nil
        }
        let view = AssetDetailsContainerViewController()

        view.content = accountView
        view.draggable = historyView
        view.hidesBottomBarWhenPushed = true
        return view
    }
}
