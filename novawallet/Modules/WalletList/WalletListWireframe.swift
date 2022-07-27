import Foundation
import UIKit

final class WalletListWireframe: WalletListWireframeProtocol {
    let walletUpdater: WalletDetailsUpdating

    init(walletUpdater: WalletDetailsUpdating) {
        self.walletUpdater = walletUpdater
    }

    func showWalletList(from view: WalletListViewProtocol?) {
        guard let accountManagement = WalletSelectionViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: accountManagement.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAssetDetails(from view: WalletListViewProtocol?, chain: ChainModel, asset: AssetModel) {
        guard let context = try? WalletContextFactory().createContext(for: chain, asset: asset) else {
            return
        }

        let assetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId).walletId

        guard let navigationController = view?.controller.navigationController else {
            return
        }

        try? context.createAssetDetails(for: assetId, in: navigationController)

        walletUpdater.context = context
    }

    func showAssetsManage(from view: WalletListViewProtocol?) {
        guard let assetsManageView = AssetsManageViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: assetsManageView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAssetsSearch(
        from view: WalletListViewProtocol?,
        initState: WalletListInitState,
        delegate: AssetsSearchDelegate
    ) {
        guard let assetsSearchView = AssetsSearchViewFactory.createView(for: initState, delegate: delegate) else {
            return
        }

        assetsSearchView.controller.modalTransitionStyle = .crossDissolve
        assetsSearchView.controller.modalPresentationStyle = .fullScreen

        view?.controller.present(assetsSearchView.controller, animated: true, completion: nil)
    }

    func showNfts(from view: WalletListViewProtocol?) {
        guard let nftListView = NftListViewFactory.createView() else {
            return
        }

        nftListView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(nftListView.controller, animated: true)
    }
}
