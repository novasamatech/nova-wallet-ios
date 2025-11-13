import Foundation
import UIKit
import UIKit_iOS

final class AssetListWireframe: AssetListWireframeProtocol {
    let assetListModelObservable: AssetListModelObservable
    let dAppMediator: DAppInteractionMediating
    let walletNotificationService: WalletNotificationServiceProtocol
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol

    init(
        assetListModelObservable: AssetListModelObservable,
        dAppMediator: DAppInteractionMediating,
        walletNotificationService: WalletNotificationServiceProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) {
        self.assetListModelObservable = assetListModelObservable
        self.dAppMediator = dAppMediator
        self.walletNotificationService = walletNotificationService
        self.delegatedAccountSyncService = delegatedAccountSyncService
    }

    func showAssetDetails(
        from view: AssetListViewProtocol?,
        chainAsset: ChainAsset
    ) {
        let swapCompletionClosure: (ChainAsset) -> Void = { [weak self, weak view] chainAsset in
            view?.controller.navigationController?.popToRootViewController(animated: false)
            self?.showAssetDetails(from: view, chainAsset: chainAsset)
        }

        let operationState = AssetOperationState(
            assetListObservable: assetListModelObservable,
            swapCompletionClosure: swapCompletionClosure
        )

        guard let assetDetailsView = AssetDetailsContainerViewFactory.createView(
            chainAsset: chainAsset,
            operationState: operationState
        ),
            let navigationController = view?.controller.navigationController else {
            return
        }
        navigationController.pushViewController(
            assetDetailsView.controller,
            animated: true
        )
    }

    func showTokensManage(from view: AssetListViewProtocol?) {
        guard let tokensManageView = TokensManageViewFactory.createView() else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: tokensManageView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
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
        assetsSearchView.controller.modalPresentationStyle = .overCurrentContext

        view?.controller.present(
            assetsSearchView.controller,
            animated: true
        )
    }

    func showSendTokens(
        from view: AssetListViewProtocol?,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) {
        guard let assetOperationView = AssetOperationViewFactory.createSendView(
            for: assetListModelObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetOperationView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showRecieveTokens(from view: AssetListViewProtocol?) {
        guard let assetOperationView = AssetOperationViewFactory.createReceiveView(for: assetListModelObservable) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetOperationView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController, animated: true,
            completion: nil
        )
    }

    func showRamp(
        from view: (any AssetListViewProtocol)?,
        action: RampActionType,
        delegate: RampFlowStartingDelegate?
    ) {
        guard let assetOperationView = AssetOperationViewFactory.createRampView(
            for: assetListModelObservable,
            action: action,
            delegate: delegate
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: assetOperationView.controller
        )

        if action == .offRamp {
            view?.controller.presentWithCardLayout(
                navigationController,
                animated: true
            )
        } else {
            view?.controller.presentWithCardLayout(
                navigationController,
                animated: true
            )
        }
    }

    func showSwapTokens(from view: AssetListViewProtocol?) {
        let completionClosure: (ChainAsset) -> Void = { [weak self] chainAsset in
            self?.showAssetDetails(from: view, chainAsset: chainAsset)
        }
        let selectClosure: SwapAssetSelectionClosure = { [weak self] chainAsset, state in
            self?.showSwapTokens(
                from: view,
                state: state,
                payAsset: chainAsset,
                swapCompletionClosure: completionClosure
            )
        }
        guard let swapDirectionsView = SwapAssetsOperationViewFactory.createSelectPayTokenView(
            for: assetListModelObservable,
            selectionModel: .payForAsset(nil),
            selectClosureStrategy: .callbackAfterDismissal,
            selectClosure: selectClosure
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: swapDirectionsView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showGift(
        from view: AssetListViewProtocol?,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) {
        guard let giftFlowView = GiftsOnboardingViewFactory.createView(
            stateObservable: assetListModelObservable,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        ) else { return }

        let navigationController = NovaNavigationController(
            rootViewController: giftFlowView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showNfts(from view: AssetListViewProtocol?) {
        guard let nftListView = NftListViewFactory.createView() else {
            return
        }

        nftListView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(
            nftListView.controller,
            animated: true
        )
    }

    func showMultisigOperations(from view: AssetListViewProtocol?) {
        guard let operationsView = MultisigOperationsViewFactory.createView() else {
            return
        }

        operationsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(
            operationsView.controller,
            animated: true
        )
    }

    func showBalanceBreakdown(from view: AssetListViewProtocol?, params: LocksViewInput) {
        guard let viewController = LocksViewFactory.createView(input: params) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.controller.modalTransitioningFactory = factory
        viewController.controller.modalPresentationStyle = .custom

        view?.controller.present(
            viewController.controller,
            animated: true
        )
    }

    func showWalletConnect(from view: AssetListViewProtocol?) {
        guard
            let walletConnectView = WalletConnectSessionsViewFactory.createViewForCurrentWallet(
                with: dAppMediator
            ) else {
            return
        }

        walletConnectView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(walletConnectView.controller, animated: true)
    }

    func showStaking(from view: AssetListViewProtocol?) {
        guard let tabBarController = view?.controller.navigationController?.tabBarController else {
            return
        }

        tabBarController.selectedIndex = MainTabBarIndex.staking
    }

    private func showSwapTokens(
        from view: AssetListViewProtocol?,
        state: SwapTokensFlowStateProtocol,
        payAsset: ChainAsset,
        swapCompletionClosure: SwapCompletionClosure?
    ) {
        guard let swapTokensView = SwapSetupViewFactory.createView(
            state: state,
            payChainAsset: payAsset,
            swapCompletionClosure: swapCompletionClosure
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: swapTokensView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showCard(
        from view: AssetListViewProtocol?,
        wallet: MetaAccountModel
    ) {
        checkingSupport(
            of: .card,
            for: wallet,
            sheetPresentingView: view
        ) {
            guard let payCardView = PayCardViewFactory.createView() else {
                return
            }

            payCardView.controller.hidesBottomBarWhenPushed = true
            view?.controller.navigationController?.pushViewController(payCardView.controller, animated: true)
        }
    }

    func dropModalFlow(
        from view: AssetListViewProtocol?,
        completion: @escaping () -> Void
    ) {
        view?.controller.presentedViewController?.dismiss(
            animated: true,
            completion: completion
        )
    }
}
