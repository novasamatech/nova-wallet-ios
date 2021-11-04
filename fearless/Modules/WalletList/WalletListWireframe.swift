import Foundation

final class WalletListWireframe: WalletListWireframeProtocol {
    func showWalletList(from view: WalletListViewProtocol?) {
        guard let accountManagement = WalletManagementViewFactory.createViewForSwitch() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountManagement.controller,
            animated: true
        )
    }

    func showAssetDetails(from view: WalletListViewProtocol?, chain: ChainModel) {
        guard
            let context = try? WalletContextFactory().createContext(for: chain),
            let asset = chain.utilityAssets().first else {
            return
        }

        let assetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId).walletId

        guard let navigationController = view?.controller.navigationController else {
            return
        }

        try? context.createAssetDetails(for: assetId, in: navigationController)
    }
}
