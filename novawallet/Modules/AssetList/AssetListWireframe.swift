import Foundation
import UIKit
import SoraUI

final class AssetListWireframe: AssetListWireframeProtocol {
    let dappMediator: DAppInteractionMediating
    let assetListModelObservable: AssetListModelObservable

    init(
        dappMediator: DAppInteractionMediating,
        assetListModelObservable: AssetListModelObservable
    ) {
        self.dappMediator = dappMediator
        self.assetListModelObservable = assetListModelObservable
    }

    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel) {
        guard let assetDetailsView = AssetDetailsContainerViewFactory.createView(
            chain: chain,
            asset: asset
        ),
            let navigationController = view?.controller.navigationController else {
            return
        }
        navigationController.pushViewController(
            assetDetailsView.controller,
            animated: true
        )
    }

    func showHistory(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel) {
        guard let history = TransactionHistoryViewFactory.createView(
            chainAsset: .init(chain: chain, asset: asset)
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.pushViewController(
            history.controller,
            animated: true
        )
    }

    func showAssetsSettings(from view: AssetListViewProtocol?) {
        guard let assetsManageView = AssetsSettingsViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetsManageView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showTokensManage(from view: AssetListViewProtocol?) {
        guard let tokensManageView = TokensManageViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: tokensManageView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showAssetsSearch(from view: AssetListViewProtocol?, delegate: AssetsSearchDelegate) {
        guard
            let assetsSearchView = AssetsSearchViewFactory.createView(
                for: assetListModelObservable,
                delegate: delegate
            ) else {
            return
        }

        assetsSearchView.controller.modalTransitionStyle = .crossDissolve
        assetsSearchView.controller.modalPresentationStyle = .fullScreen

        view?.controller.present(assetsSearchView.controller, animated: true, completion: nil)
    }

    func showSendTokens(
        from view: AssetListViewProtocol?,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) {
        guard let assetsSearchView = AssetOperationViewFactory.createSendView(
            for: assetListModelObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetsSearchView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRecieveTokens(from view: AssetListViewProtocol?) {
        guard let assetsSearchView = AssetOperationViewFactory.createReceiveView(for: assetListModelObservable) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetsSearchView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showBuyTokens(from view: AssetListViewProtocol?) {
        guard let assetsSearchView = AssetOperationViewFactory.createBuyView(for: assetListModelObservable) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetsSearchView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showSwapTokens(from view: AssetListViewProtocol?) {
        guard let swapTokensView = SwapSetupViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: swapTokensView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showNfts(from view: AssetListViewProtocol?) {
        guard let nftListView = NftListViewFactory.createView() else {
            return
        }

        nftListView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(nftListView.controller, animated: true)
    }

    func showBalanceBreakdown(from view: AssetListViewProtocol?, params: LocksViewInput) {
        guard let viewController = LocksViewFactory.createView(input: params) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.controller.modalTransitioningFactory = factory
        viewController.controller.modalPresentationStyle = .custom

        view?.controller.present(viewController.controller, animated: true)
    }

    func showWalletConnect(from view: AssetListViewProtocol?) {
        guard
            let walletConnectView = WalletConnectSessionsViewFactory.createViewForCurrentWallet(
                with: dappMediator
            ) else {
            return
        }

        walletConnectView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(walletConnectView.controller, animated: true)
    }
}
