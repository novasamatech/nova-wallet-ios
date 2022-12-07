import Foundation
import UIKit
import SoraUI

final class AssetListWireframe: AssetListWireframeProtocol {
    let walletUpdater: WalletDetailsUpdating

    init(walletUpdater: WalletDetailsUpdating) {
        self.walletUpdater = walletUpdater
    }

    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel) {
        guard let assetDetailsView = AssetDetailsViewFactory.createView(
            chain: chain,
            asset: asset
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.pushViewController(
            assetDetailsView.controller,
            animated: true
        )
    }

    func showAssetsManage(from view: AssetListViewProtocol?) {
        guard let assetsManageView = AssetsManageViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: assetsManageView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAssetsSearch(
        from view: AssetListViewProtocol?,
        initState: AssetListInitState,
        delegate: AssetsSearchDelegate
    ) {
        guard let assetsSearchView = AssetsSearchViewFactory.createView(for: initState, delegate: delegate) else {
            return
        }

        assetsSearchView.controller.modalTransitionStyle = .crossDissolve
        assetsSearchView.controller.modalPresentationStyle = .fullScreen

        view?.controller.present(assetsSearchView.controller, animated: true, completion: nil)
    }

    func showNfts(from view: AssetListViewProtocol?) {
        guard let nftListView = NftListViewFactory.createView() else {
            return
        }

        nftListView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(nftListView.controller, animated: true)
    }

    func showBalanceBreakdown(
        from view: AssetListViewProtocol?,
        prices: [ChainAssetId: PriceData],
        balances: [AssetBalance],
        chains: [ChainModel.Id: ChainModel],
        locks: [AssetLock],
        crowdloans: [ChainModel.Id: [CrowdloanContributionData]]
    ) {
        guard let viewController = LocksViewFactory.createView(input:
            .init(
                prices: prices,
                balances: balances,
                chains: chains,
                locks: locks,
                crowdloans: crowdloans
            )) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.controller.modalTransitioningFactory = factory
        viewController.controller.modalPresentationStyle = .custom

        view?.controller.present(viewController.controller, animated: true)
    }
}
