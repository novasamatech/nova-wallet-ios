import SoraFoundation

final class AssetDetailsContainerViewFactory: AssetDetailsContainerViewFactoryProtocol {
    static func createView(chain: ChainModel, asset: AssetModel) -> AssetDetailsContainerViewProtocol? {
        let view = AssetDetailsContainerViewController(localizationManager: LocalizationManager.shared)

        guard
            let accountView = AssetDetailsViewFactory.createView(
                chain: chain,
                asset: asset
            ),
            let historyView = TransactionHistoryViewFactory.createView(chainAsset: .init(chain: chain, asset: asset)) else {
            return nil
        }

        view.content = accountView
        view.draggable = historyView

        return view
    }
}
